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
  @@vg = nil

  def post_init
    super
    @@vg ||= NVG::Context.new
  end

  def vg
    @@vg
  end
end

# Module for adding tagging capabilities to Objects, the object in question
# must implement a tags accessor, which is normally an Array of Strings.
module Taggable
  def tag(*tgs)
    tags.concat tgs
  end

  def untag(*tgs)
    self.tags -= tgs
  end

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

  def render(rect, options = {})
  end
end

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

class GridOverlay < BaseObject
  field :color, type: NVG::Color, default: proc { NVG.mono(0) }

  def render(rect, options = {})
    x, y, w, h = *rect
    x2 = x + w
    y2 = y + h
    vg.draw w, h, 1.0 do |v|
      cols = w.divceil(16)
      rows = h.divceil(16)
      v.stroke_color @color
      cols.times do |xx|
        col = x + xx * 16
        v.move_to col, y
        v.line_to col, y2
      end
      rows.times do |yy|
        row = y + yy * 16
        v.move_to x, row
        v.line_to x2, row
      end
      v.stroke
    end
  end
end

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
      screen.clear_color = Color.mono 107
      @scene = Scene.new tags: ['root']
      @scene.add GridOverlay.new color: NVG.mono(117), tags: ['map_grid']
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
