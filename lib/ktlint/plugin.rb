require 'json'

module Danger
  # Kotlin Lint files of a gradle based Android project.
  # This is done using the Pinterest's [ktlint](https://ktlint.github.io/) tool.
  # Results are passed out as tables in markdown.
  #
  # @example Running AndroidLint with its basic configuration
  #
  #          ktlint.lint
  #
  # @example Running ktlint with a specific gradle task
  #
  #          ktlint.gradle_task = "ktlintMyFlavorVariantCheck"
  #          ktlint.lint
  #
  # @example Running AndroidLint without running a Gradle task
  #
  #          ktlint.skip_gradle_task = true
  #          ktlint.lint
  #
  # @see  SaezChristopher/danger-ktlint
  # @tags ktlint
  #
  #
  class DangerKtlint < Plugin

    # Location of ktlint report file
    # If your ktlint task outputs to a different location, you can specify it here.
    # Defaults to "app/build/reports/ktlint/ktlintSourceSetCheck.json". Be carefull only json output is supported for the moment
    # @return [String]
    attr_accessor :report_file

    # A getter for `report_file`. You can add multiple files but separeted by commas
    # @example "file.json,file2.json"
    # @return [String]
    def report_file
      @report_file || 'app/build/reports/ktlint/ktlintSourceSetCheck.json'
    end

    # Custom gradle task to run.
    # This is useful when your project has different flavors.
    # Defaults to "ktlintCheck".
    # @return [String]
    attr_accessor :gradle_task

    # A getter for `gradle_task`, returning "lint" if value is nil.
    # @return [String]
    def gradle_task
      @gradle_task ||= "ktlintCheck"
    end

    # Skip Gradle task.
    # This is useful when Gradle task has been already executed.
    # Defaults to `false`.
    # @return [Boolean]
    attr_writer :skip_gradle_task

    # A getter for `skip_gradle_task`, returning `false` if value is nil.
    # @return [Boolean]
    def skip_gradle_task
      @skip_gradle_task ||= false
    end

    # run Ktlint only on stagged file instead of all project file
    # Defaults to `false`.
    # @return [Boolean]
    attr_accessor :use_staged_file_only

    # A getter for `use_staged_file_only`, returning `false` if value is nil.
    # @return [Boolean]
    def use_staged_file_only
      @use_staged_file_only ||= false
    end

    attr_accessor :treat_errors_as_warnings

    # A getter for `treat_errors_as_warnings`, returning `false` if value is nil.
    # @return [Boolean]
    def treat_errors_as_warnings
      @treat_errors_as_warnings ||= true
    end

    # Calls lint task of your gradle project.
    # It fails if `gradlew` cannot be found inside current directory.
    # It fails if json reports cannot be found.
    # @return [void]
    #
    def lint(inline_mode: false)
      unless skip_gradle_task
        return fail("Could not find `gradlew` inside current directory") unless gradlew_exists?
      end

      unless skip_gradle_task
        if use_staged_file_only
          targets = target_files(git.added_files + git.modified_files)
          system "./gradlew #{gradle_task} -PinternalKtlintGitFilter=\"#{targets.join('\n')}\"" #todo make it work
        else
          system "./gradlew #{gradle_task}"
        end
      end

      json_files = report_file.split(',')
      results = []
      json_files.each do |jsonFile|
        unless File.exists?(jsonFile)
          next
        end
        results += JSON.parse(File.read(jsonFile))
      end
      if results.empty?
        print("Skipping ktlinting because no report files available")
      end

      if inline_mode
        send_inline_comments(results)
      else
        send_markdown_comment(results)
      end
    end

    private

    def send_markdown_comment(results)
        results.each do |result|
          result['errors'].each do |error|
            file = "#{result['file']}#L#{error['line']}"
            message = "#{github.html_link(file)}: #{error['message']}"
            send(treat_errors_as_warnings === true ? "warn" : "fail", message)
            #fail(message)
          end
        end
    end

    def send_inline_comments(results)
        results.each do |result|
          result['errors'].each do |error|
            #file = result['file']
            message = error['message']
            line = error['line']
            send(treat_errors_as_warnings === true ? "warn" : "fail", message, file: result['file'], line: line)
            #fail(message, file: result['file'], line: line)
          end
        end
    end

    def target_files(changed_files)
      changed_files.select do |file|
        file.end_with?('.kt')
      end
    end

    def gradlew_exists?
      `ls gradlew`.strip.empty? == false
    end

    private

    end
end