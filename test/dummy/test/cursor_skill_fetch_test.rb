# frozen_string_literal: true

require "test_helper"

class CursorSkillFetchTest < ActiveSupport::TestCase
  test "fetch-skills extras come from the plugin catalog without hardcoded extra URLs" do
    root = GemTemplate::Engine.root
    script = File.read(root.join(".cursor/fetch-skills.sh"))
    install = File.read(root.join(".cursor/install.sh"))

    gitignore = File.read(root.join(".gitignore"))

    assert_includes install, "fetch-skills.sh"
    assert_includes script, "skill-sources.json"
    assert_includes script, "contents/rules"
    assert_includes gitignore, ".cursor/skills/"
    assert_includes gitignore, ".cursor/rules/"
    refute_includes script, "cursor/plugins"
    refute_includes script, "poteto-mode"
    refute_includes script, "pstack"
    refute_includes script, "${HOME}/.cursor/rules"
    assert_includes script, 'RULES_DIR="${ROOT}/.cursor/rules"'
  end

  test "gem version stays 0.2.3 and gemspec still excludes .cursor" do
    assert_equal "0.2.3", GemTemplate::VERSION

    spec = Gem::Specification.load(GemTemplate::Engine.root.join("gem_template.gemspec").to_s)
    cursor_files = spec.files.select { |path| path == ".cursor" || path.split("/").include?(".cursor") }

    assert_empty cursor_files

    tracked = `git -C #{GemTemplate::Engine.root} ls-files -- .cursor/rules`
    assert_equal "", tracked.strip
  end
end
