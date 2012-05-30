class SmokeTestTask
  include ::Rake::DSL if defined?(::Rake::DSL)
  def initialize(task_name=:smoke, tests)
    @task_name = task_name

    desc "Smoke Test"
    task @task_name do
      # when using Hash, tasks may run in parallel. a new multitask
      # named group_name is created, which runs dependencies group_tasks
      # in parallel. Tasks in group_tasks must be defined beforehand
      if Hash === tests do
        tests.each do |group_name, group_tasks|
          multitask group_name => group_tasks
          Rake::MultiTask[group_name].invoke
        end
      # when using an Array, tasks are run sequentially. These tasks
      # should already be defined beforehand
      elsif Array === tests do
        tests.each do |t|
          Rake::Task[t].invoke
        end
      # currently, only Hash and Array task lists are supported
      else
        raise "tests must be either Hash or Array"
      end
    end
  end
end
