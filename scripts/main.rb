# Bootstrapped moon player entry point
#
# @param [Moon::Engine] engine
# @param [Float] delta
# @return [Void]
def step(engine, delta)
  @state_manager ||= Moon::StateManager.new(engine).tap do |s|
    s.push States::MapEditor
  end
  @state_manager.step delta
end
