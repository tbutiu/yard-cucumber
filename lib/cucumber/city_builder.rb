
module Cucumber
  module Parser
    class CityBuilder
      include Gherkin::Rubify

      def initialize(file)
        @file = file
      end

      def ast
        @feature || @multiline_arg
      end

      def find_or_create_tag(tag_name,parent)
        #log.debug "Processing tag #{tag_name}"
        tag_code_object = YARD::Registry.all(:tag).find {|tag| tag.value == tag_name } || 
        YARD::CodeObjects::Cucumber::Tag.new(YARD::CodeObjects::Cucumber::CUCUMBER_TAG_NAMESPACE,tag_name.gsub('@','')) {|t| t.owners = [] ; t.value = tag_name }

        parent.tags << tag_code_object
        tag_code_object.add_file(@file,parent.line)
        tag_code_object.owners << parent
      end

      def feature(feature)
        #log.debug  "FEATURE: #{feature.name} #{feature.line} #{feature.keyword} #{feature.description}"
        @feature = YARD::CodeObjects::Cucumber::Feature.new(YARD::CodeObjects::Cucumber::CUCUMBER_FEATURE_NAMESPACE,@file.gsub(/\/|\./,'_')) do |f|
          f.comments = feature.comments.map{|comment| comment.value}.join("\n")
          f.description = feature.description
          f.add_file(@file,feature.line)
          f.keyword = feature.keyword
          f.value = feature.name
          f.tags = []

          feature.tags.each {|feature_tag| find_or_create_tag(feature_tag.name,f) }
        end
      end

      def background(background)
        #log.debug "BACKGROUND #{background.keyword} #{background.name} #{background.line} #{background.description}"
        @background = YARD::CodeObjects::Cucumber::Scenario.new(@feature,"background") do |b|
          b.comments = background.comments.map{|comment| comment.value}.join("\n")
          b.description = background.description
          b.keyword = background.keyword
          b.value = background.name
          b.add_file(@file,background.line)
        end

        @feature.background = @background
        @background.feature = @feature
        @step_container = @background
      end

      def scenario(statement)
        #log.debug "SCENARIO"
        scenario = YARD::CodeObjects::Cucumber::Scenario.new(@feature,"scenario_#{@feature.scenarios.length + 1}") do |s|
          s.comments = statement.comments.map{|comment| comment.value}.join("\n")
          s.description = statement.description
          s.add_file(@file,statement.line)
          s.keyword = statement.keyword
          s.value = statement.name

          statement.tags.each {|scenario_tag| find_or_create_tag(scenario_tag.name,s) }
        end

        scenario.feature = @feature
        @feature.scenarios << scenario
        @step_container = scenario
      end

      def scenario_outline(statement)
        scenario(statement)
      end

      def examples(examples)
        #log.debug "EXAMPLES"
        @step_container.examples << [
          examples.keyword,
          examples.name,
          examples.line,
          examples.comments.map{|comment| comment.value}.join("\n"),
          matrix(examples.rows) ]
        end

        def step(step)
          #log.debug "STEP #{step.multiline_arg}"
          @table_owner = YARD::CodeObjects::Cucumber::Step.new(@step_container,"#{step.line}") do |s|
            s.keyword = step.keyword
            s.value = step.name
            s.add_file(@file,step.line)
          end

          multiline_arg = rubify(step.multiline_arg)
          case(multiline_arg)
          when Gherkin::Formatter::Model::PyString
            @table_owner.text = multiline_arg.value
          when Array
            @table_owner.table = matrix(multiline_arg)
          end

          @table_owner.scenario = @step_container
          @step_container.steps << @table_owner
        end

        def eof
        end

        def syntax_error(state, event, legal_events, line)
          # raise "SYNTAX ERROR"
        end

        private

        def matrix(gherkin_table)
          gherkin_table.map do |gherkin_row|
            row = gherkin_row.cells
            class << row
              attr_accessor :line
            end
            row.line = gherkin_row.line
            row
          end
        end
      end
    end
  end
