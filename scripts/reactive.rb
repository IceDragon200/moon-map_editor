module Reactive
  module Observable
    # @param [#call] listener
    # @return [Object] same listener given
    def subscribe(listener = nil, &block)
      l = listener || block
      raise unless l
      listeners.push l
      listener
    end

    # @param [#call] listener
    # @return [Object] listener removed
    def unsubscribe(listener)
      listeners.delete listener
    end

    # @param [Object] *args
    def notify(*args)
      listeners.each do |listener|
        listener.call *args
      end
    end
  end

  module Reactable
    include Observable

    # Subscribes the given listener to the current object, also subscribes
    # the block to the listener if given.
    #
    # @param [#call] listener
    # @param [#call] block
    # @return [Object] same listener given
    def attach(listener, block = nil)
      subscribe(listener).tap { |s| s.subscribe(block) if block }
    end

    def reduce(cb = nil, &block)
      attach Reducer.new(&block), cb
    end

    def select(cb = nil, &block)
      attach Selector.new(&block), cb
    end

    def reject(cb = nil, &block)
      attach Rejector.new(&block), cb
    end

    def map(cb = nil, &block)
      attach Mapper.new(&block), cb
    end

    def buffer(length, &block)
      attach Buffer.new(length), block
    end

    def accumulate(length, &block)
      attach Accumulator.new(length), block
    end

    def with_index(&block)
      attach Indexer.new, block
    end

    def case(clause, &block)
      select(block) { |*a| clause === a.singularize }
    end

    def eq(other, &block)
      select(block) { |*a| other == a.singularize }
    end

    def not_eq(other, &block)
      reject(block) { |*a| other == a.singularize }
    end
  end

  class Reactor
    include Reactable

    # @api
    attr_accessor :listeners
    attr_accessor :tags

    def initialize
      @listeners = []
      @tags = []
    end

    def call(*args)
      @last_values = args
      invoke(*args)
    end

    def invoke(*args)
      notify(*args)
    end
  end

  class Indexer < Reactor
    attr_accessor :index

    def initialize
      super
      @index = 0
    end

    def invoke(*args)
      notify(*args, @index)
      @index += 1
    end
  end

  class Accumulator < Reactor
    attr_reader :length

    def initialize(length)
      super()
      @length = length
      @b = []
    end

    def flush
      notify @b
    end

    def invoke(*args)
      @b << args.singularize
      if @b.size >= @length
        flush
        @b.clear
      end
    end
  end

  class Buffer < Accumulator
    def flush
      @b.each { |*a| notify(*a) }
    end
  end

  class Reducer < Reactor
    def initialize(&block)
      super()
      @func = block
    end

    def invoke(*args)
      @func.call(*args)
      notify(*args)
    end
  end

  class Conditioner < Reducer
    def initialize(&block)
      super(&block)
      @else_listeners = Reactor.new
    end

    def else(&block)
      if block
        @else_listeners.reduce(&block)
      else
        @else_listeners
      end
    end

    def invoke(*args)
      if @func.call(*args)
        on_true(*args)
      else
        on_false(*args)
      end
    end
  end

  class Selector < Conditioner
    def on_false(*args)
      @else_listeners.call(*args)
    end

    def on_true(*args)
      notify(*args)
    end
  end

  class Rejector < Conditioner
    def on_true(*args)
      @else_listeners.call(*args)
    end

    def on_false(*args)
      notify(*args)
    end
  end

  class Mapper < Reducer
    def invoke(*args)
      notify @func.call(*args)
    end
  end
end
