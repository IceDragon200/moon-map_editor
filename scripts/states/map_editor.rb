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

module Visibility
  ##
  # Is this visible?
  #
  # @return [Boolean]
  def visible?
    !!visible
  end

  ##
  # Is this invisible?
  #
  # @return [Boolean]
  def invisible?
    !visible
  end

  ##
  # Sets visible to false
  #
  # @return [self]
  def hide
    self.visible = false
    self
  end

  ##
  # Sets visible to true
  #
  # @return [self]
  def show
    self.visible = true
    self
  end
end

module Renderable
  class << self
    attr_accessor :vg
  end

  include Visibility

  def vg
    Renderable.vg
  end

  def render_content(ctx, rect, options = {})
  end

  def render(ctx, rect, options = {})
    render_content ctx, rect, options if visible?
  end
end

class BaseObject < Moon::DataModel::Metal
  include Renderable
  include Taggable

  field :visible, type: Boolean, default: true
  array :tags, type: String

  def update(delta)
  end
end

# Offseting view
class View < BaseObject
  field :offset, type: Moon::Vector2, default: proc { Moon::Vector2.zero }
  field :child,  type: Renderable,    default: nil

  def render_child(ctx, rect, options = {})
    @child.render ctx, rect, options if @child
  end

  def render_content(ctx, rect, options = {})
    render_child ctx, rect.translate(offset), options
  end
end

# Grid overlay for the screen
class GridOverlay < BaseObject
  field :reso,  type: Moon::Vector2, default: proc { Moon::Vector2.new(8, 8) }
  field :color, type: NVG::Color, default: proc { NVG.mono(0) }

  def render_content(ctx, rect, options = {})
    x, y, w, h = *rect
    x2 = x + w
    y2 = y + h
    cols = w.divceil(reso.x)
    rows = h.divceil(reso.y)
    vg.draw w, h, 1.0 do
      vg.scale ctx.scale, ctx.scale
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

  def render_content(ctx, rect, options = {})
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

  def render_content(ctx, rect, options = {})
    vg.draw rect.w, rect.h, 1.0 do
      vg.stroke_color color
      vg.path do
        vg.scale ctx.scale, ctx.scale
        vg.rect rect.x + coord.x * reso.x + 1, rect.y + coord.y * reso.y + 1,
                reso.x - 2, reso.y - 2
        vg.stroke_width 1
        vg.stroke
      end
    end
  end
end

class CursorPosition < BaseObject
  field :cursor, type: Cursor

  def render_content(ctx, rect, options)
    vg.draw rect.w, rect.h, 1.0 do
      vg.fill_color NVG.rgba(32, 32, 32, 128)
      vg.path do
        vg.rounded_box rect.x + 8, rect.y + 8, 196, 32, 8, 8, 8, 8
        vg.fill
      end
      vg.text_align NVG::ALIGN_CENTER | NVG::ALIGN_TOP
      vg.fill_color NVG.mono(255)
      vg.text rect.x + (196 / 2), rect.y + 8, cursor.coord.to_s
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
  def render_content(ctx, rect, options = {})
    @children.each do |node|
      node.value.render ctx, rect, options
    end
    self
  end
end

class InputReactor < Moon::DataModel::Metal
  include Reactive::Reactable

  array :listeners, type: Object

  def trigger(event)
    notify event
  end

  def on(action, *keys, &block)
    action_filter = select { |e| e.type == action }.select { |e| e.action == action }
    keys.each { |key| action_filter.select(block) { |e| e.key == key } }
  end
end

class InputPoll < Moon::DataModel::Metal
  dict :keys, key: Symbol, value: Symbol

  def pressed?(key)
    keys[key] == :press
  end

  def repeated?(key)
    keys[key] == :repeat
  end

  def released?(key)
    keys[key] == :release
  end

  alias :down? :pressed?
  alias :up? :released?
end

module States #:nodoc:
  # Main MapEditor state
  class MapEditor < ::State
    def init
      super
      Renderable.vg ||= begin
        ctx = NVG::Context.new NVG::ANTIALIAS
        ctx.create_font 'vera', 'resources/fonts/vera/Vera.ttf'
        ctx.font_face 'vera'
        ctx
      end
      create_all
    end

    private def create_all
      reso = Moon::Vector2.new 8, 8

      data = Moon::Table.new 20, 20, default: -1
      data.map_with_xy { |_, _, _| [32, 33, 34, 35].sample }
      tileset = Moon::Spritesheet.new 'resources/world.png', reso.x, reso.y

      @scene = Scene.new tags: ['root']

      @cursor = Cursor.new color: NVG.mono(168), reso: reso, tags: ['map_cursor']
      map_scene = Scene.new tags: ['map_view']
      map_scene.add GridOverlay.new color: NVG.mono(117), tags: ['map_grid'], reso: reso
      map_scene.add Tilemap.new data: data, sprite: tileset
      map_scene.add @cursor
      @scene.add View.new child: map_scene

      gui_scene = Scene.new tags: ['gui_view']
      gui_scene.add CursorPosition.new cursor: @cursor
      @scene.add View.new child: gui_scene

      register_input
    end

    def register_input
      @input = InputReactor.new
      @input_poll = InputPoll.new
      @input.case(Moon::InputEvent) { |e| @input_poll.keys[e.key] = e.action }
      engine.input.register @input

      # So we can close the game.
      @input.on :press, :escape do
        engine.quit
      end

      @input.case(Moon::InputEvent) do |e|
        v = e.action == :press ? 1 : 0
        case e.key
        when :left
          @cursor.coord.x -= v
        when :right
          @cursor.coord.x += v
        when :up
          @cursor.coord.y -= v
        when :down
          @cursor.coord.y += v
        end
      end
    end

    def start
      super
      screen.clear_color = Color.mono 107
      screen.scale = 4
    end

    def terminate
      engine.input.unregister @input
      super
    end

    def update(delta)
      @scene.update delta
      super
    end

    def render
      @scene.render screen, screen.rect
      super
    end
  end
end
