module Enumerable
  # Checks if the enum includes all elements from the slice
  #
  # @param [Enumerable] slic
  # @return [Boolean] true if the enum includes all the elements from the slice
  def include_slice?(slic)
    slic.all? { |e| include?(e) }
  end
end

class Numeric #:nodoc:
  # Divides the numeric followed by rounding using #ceil
  #
  # @param [Numeric] n
  def divceil(n)
    self.div(n).ceil
  end
end

# Utility class for creating Vector4 colors from RGBA8 values
class Color
  # normalized values
  #
  # @param [Float] r
  # @param [Float] g
  # @param [Float] b
  # @param [Float] a
  # @return [Moon::Vector4]
  def self.new(r, g, b, a)
    Moon::Vector4.new r, g, b, a
  end

  # Creates a RGBA color from the given r, g, b, a values
  # @param [Integer] r
  # @param [Integer] g
  # @param [Integer] b
  # @param [Integer] a
  # @return [Moon::Vector4]
  def self.rgba(r, g, b, a)
    new r / 255.0, g / 255.0, b / 255.0, a / 255.0
  end

  # Creates a RGB color from the given r, g, b values
  #
  # @param [Integer] r
  # @param [Integer] g
  # @param [Integer] b
  # @return [Moon::Vector4]
  def self.rgb(r, g, b)
    rgba r, g, b, 255
  end

  # Creates a monochrome color from the given value +c+
  #
  # @param [Integer] c
  # @return [Moon::Vector4]
  def self.mono(c)
    rgb c, c, c
  end
end

module Renderable
  class << self
    attr_accessor :vg
  end

  def vg
    Renderable.vg
  end

  def render(rect, options = {})
  end
end

# Module for adding tagging capabilities to Objects, the object in question
# must implement a tags accessor, which is normally an Array of Strings.
module Taggable
  # Adds new tags to the object
  #
  # @param [String] tgs
  def tag(*tgs)
    tags.concat tgs
  end

  # Removes tags from the object
  #
  # @param [String] tgs
  def untag(*tgs)
    self.tags -= tgs
  end

  # Checks if the object includes the tags
  #
  # @param [String] tgs
  def tagged?(*tgs)
    tags.include_slice?(tgs)
  end
end

class BaseObject < Moon::DataModel::Metal
  include Renderable
  include Taggable

  array :tags, type: String

  def update(delta)
  end
end

# Offseting view
class View < BaseObject
  field :offset, type: Moon::Vector2, default: proc { Moon::Vector2.zero }
  field :child,  type: Renderable,    default: nil

  def render_content(rect, options = {})
    @child.render rect, options if @child
  end

  def render(rect, options = {})
    render_content rect.translate(offset), options
  end
end

# Grid overlay for the screen
class GridOverlay < BaseObject
  field :reso,  type: Moon::Vector2, default: proc { Moon::Vector2.new(8, 8) }
  field :color, type: NVG::Color, default: proc { NVG.mono(0) }

  def render(rect, options = {})
    x, y, w, h = *rect
    x2 = x + w
    y2 = y + h
    cols = w.divceil(reso.x)
    rows = h.divceil(reso.y)
    vg.draw w, h, 1.0 do
      vg.stroke_color @color
      vg.stroke_width 1
      vg.path do
        cols.times do |xx|
          col = x + xx * reso.x
          vg.move_to col, y
          vg.line_to col, y2
        end
        rows.times do |yy|
          row = y + yy * reso.y
          vg.move_to x, row
          vg.line_to x2, row
        end
        vg.stroke
      end
    end
  end
end

class Tilemap < BaseObject
  field :data,   type: Moon::Table,       default: nil
  field :sprite, type: Moon::Spritesheet, default: nil

  def render(rect, options = {})
    return unless sprite
    return unless data
    x, y = rect.x, rect.y
    w, h = sprite.w, sprite.h
    data.iter.each_with_xy do |n, dx, dy|
      next unless n >= 0
      sprite.render x + dx * w, y + dy * h, 1, n
    end
  end
end

class Cursor < BaseObject
  field :reso,  type: Moon::Vector2, default: proc { Moon::Vector2.new(8, 8) }
  field :coord, type: Moon::Vector2, default: proc { Moon::Vector2.zero }
  field :color, type: NVG::Color

  def render(rect, options = {})
    vg.draw rect.w, rect.h, 1.0 do
      vg.stroke_color color
      vg.path do
        vg.move_to coord.x * reso.x, coord.y * reso.y
        vg.rect 1, 1, reso.x - 2, reso.y - 2
        vg.stroke_width 1
        vg.stroke
      end
    end
  end
end

class CursorPosition < BaseObject
  field :cursor, type: Cursor

  def render(rect, options)
    vg.draw rect.w, rect.h, 1.0 do
      vg.fill_color NVG.rgba(32, 32, 32, 64)
      vg.path do
        vg.rounded_box 8, 8, 196, 32, 8, 8, 8, 8
        vg.fill
      end
    end
  end
end

# Class for hosting other BaseObjects
class Scene < BaseObject
  # Post initialization
  #
  # @return [Void]
  def post_init
    super
    @children = Moon::Tree.new
  end

  # Adds a new object to the Scene tree
  #
  # @param [BaseObject] object
  # @return [self]
  def add(object)
    @children.add object
    self
  end

  # Removes an object from the Scene tree
  #
  # @param [BaseObject] object
  # @return [Void]
  def delete(object)
    @children.delete object
  end

  # Updates each node in the Scene
  #
  # @param [Float] delta
  # @return [self]
  def update(delta)
    @children.each do |node|
      node.value.update delta
    end
    self
  end

  # Renders each node in the Scene
  #
  # @param [Moon::Rect] rect
  # @param [Hash] options
  # @return [self]
  def render(rect, options = {})
    @children.each do |node|
      node.value.render rect, options
    end
    self
  end
end

module States
  class MapEditor < ::State
    def init
      super
      Renderable.vg ||= NVG::Context.new NVG::ANTIALIAS
      screen.clear_color = Color.mono 107

      reso = Moon::Vector2.new 8, 8

      data = Moon::Table.new 20, 20, default: -1
      data.map_with_xy { |_, _, _| [32, 33, 34, 35].sample }
      #pnt = Moon::Painter2.new data
      #pnt.fill 32
      tileset = Moon::Spritesheet.new 'resources/world.png', reso.x, reso.y

      @scene = Scene.new tags: ['root']
      cursor = Cursor.new color: NVG.mono(168), reso: reso, tags: ['map_cursor']
      map_scene = Scene.new tags: ['map_view']
      map_scene.add GridOverlay.new color: NVG.mono(117), tags: ['map_grid'], reso: reso
      map_scene.add Tilemap.new data: data, sprite: tileset
      map_scene.add cursor
      @scene.add View.new child: map_scene
      gui_scene = Scene.new tags: ['gui_view']
      gui_scene.add CursorPosition.new cursor: cursor
      @scene.add View.new child: gui_scene
    end

    def update(delta)
      @scene.update delta
      super
    end

    def render
      @scene.render screen.rect
      super
    end
  end
end
