# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

class FetchSkillsTest < Minitest::Test
  SCRIPT = File.expand_path("../.cursor/fetch-skills.sh", __dir__)
  PLUGIN_CONTENTS =
    "https://api.github.com/repos/bowerbird-app/RecordingStudio_cursor_plugin/contents/skills?ref=main&per_page=100"
  PLUGIN_SKILL =
    "https://raw.githubusercontent.com/bowerbird-app/RecordingStudio_cursor_plugin/main/skills/recording-studio-gems/SKILL.md"
  CATALOG =
    "https://raw.githubusercontent.com/bowerbird-app/RecordingStudio_cursor_plugin/main/skill-sources.json"
  EXTRA_CONTENTS = "https://api.github.com/repos/example/extra-skills/contents/skills?ref=main"
  EXTRA_RAW_BASE = "https://raw.githubusercontent.com/example/extra-skills/main/skills"
  EXTRA_SKILL = "#{EXTRA_RAW_BASE}/catalog-skill/SKILL.md".freeze
  EMPTY_NAME_SKILL = "#{EXTRA_RAW_BASE}/SKILL.md".freeze
  PLUGIN_RULES =
    "https://api.github.com/repos/bowerbird-app/RecordingStudio_cursor_plugin/contents/rules?ref=main"
  PLUGIN_RULES_RAW =
    "https://raw.githubusercontent.com/bowerbird-app/RecordingStudio_cursor_plugin/main/rules"
  PLUGIN_RULE = "#{PLUGIN_RULES_RAW}/flatpack-ui.mdc".freeze
  PLUGIN_RULE_COPY = "#{PLUGIN_RULES_RAW}/user-facing-copy.mdc".freeze
  PLUGIN_RULE_NOTES = "#{PLUGIN_RULES_RAW}/notes.md".freeze

  def test_script_does_not_hardcode_extra_skill_urls
    script = File.read(SCRIPT)

    refute_includes script, "cursor/plugins"
    refute_includes script, "poteto-mode"
    refute_includes script, "pstack"
    refute_includes script, "${HOME}/.cursor/rules"
    refute_includes script, "git clone"
    assert_includes script, "skill-sources.json"
    assert_includes script, "contents/rules"
    assert_includes script, 'RULES_DIR="${ROOT}/.cursor/rules"'
  end

  def test_catalog_lists_dirs_and_fetches_each_skill_md
    result = run_fetch(
      responses.merge(
        CATALOG => ok(catalog_json),
        EXTRA_CONTENTS => ok(extra_listing_json),
        EXTRA_SKILL => ok("# catalog-skill\n")
      )
    )

    assert_equal 0, result[:status]
    assert_equal "# recording-studio-gems\n", result[:skills]["recording-studio-gems"]
    assert_equal "# catalog-skill\n", result[:skills]["catalog-skill"]
    refute_includes result[:skills].keys, "add-skill-or-agent"
    refute_includes result[:skills].keys, "unrelated-skill"
    refute_includes result[:skills].keys, "README.md"
    assert_includes result[:urls], PLUGIN_CONTENTS
    assert_includes result[:urls], PLUGIN_SKILL
    assert_includes result[:urls], CATALOG
    assert_includes result[:urls], EXTRA_CONTENTS
    assert_includes result[:urls], EXTRA_SKILL
    refute_includes result[:urls], EMPTY_NAME_SKILL
    refute_includes result[:urls].join("\n"), "cursor/plugins"
    refute_includes result[:urls].join("\n"), "poteto-mode"
  end

  def test_catalog_404_skips_extras_and_still_fetches_recording_studio_skills
    result = run_fetch(responses.merge(CATALOG => { "status" => 404, "body" => "Not Found" }))

    assert_equal 0, result[:status]
    assert_equal "# recording-studio-gems\n", result[:skills]["recording-studio-gems"]
    refute_includes result[:skills].keys, "catalog-skill"
    assert_includes result[:stderr], "skill-sources.json unavailable"
    assert_includes result[:stderr], "skipping extras"
    assert_includes result[:urls], PLUGIN_SKILL
    assert_includes result[:urls], CATALOG
    refute_includes result[:urls], EXTRA_CONTENTS
    refute_includes result[:urls], EXTRA_SKILL
  end

  def test_invalid_catalog_json_skips_extras_and_exits_zero
    result = run_fetch(responses.merge(CATALOG => ok("{not json")))

    assert_equal 0, result[:status]
    assert_equal "# recording-studio-gems\n", result[:skills]["recording-studio-gems"]
    refute_includes result[:skills].keys, "catalog-skill"
    assert_includes result[:stderr], "invalid JSON"
    assert_includes result[:stderr], "skipping extras"
    refute_includes result[:urls], EXTRA_CONTENTS
    refute_includes result[:urls], EXTRA_SKILL
  end

  def test_catalog_missing_sources_skips_extras_and_exits_zero
    result = run_fetch(responses.merge(CATALOG => ok({ "not_sources" => [] }.to_json)))

    assert_equal 0, result[:status]
    assert_equal "# recording-studio-gems\n", result[:skills]["recording-studio-gems"]
    refute_includes result[:skills].keys, "catalog-skill"
    assert_includes result[:stderr], "no sources"
    assert_includes result[:stderr], "skipping extras"
    refute_includes result[:urls], EXTRA_CONTENTS
  end

  def test_plugin_rules_mdc_files_land_under_cursor_rules
    result = run_fetch(
      responses.merge(
        PLUGIN_RULES => ok(rules_listing_json),
        PLUGIN_RULE => ok("# flatpack-ui\n")
      )
    )

    assert_equal 0, result[:status]
    assert_equal "# recording-studio-gems\n", result[:skills]["recording-studio-gems"]
    assert_equal "# flatpack-ui\n", result[:rules]["flatpack-ui.mdc"]
    refute_includes result[:rules].keys, "notes.md"
    refute_includes result[:rules].keys, "README.md"
    refute_includes result[:rules].keys, "nested"
    assert_includes result[:urls], PLUGIN_CONTENTS
    assert_includes result[:urls], PLUGIN_SKILL
    assert_includes result[:urls], PLUGIN_RULES
    assert_includes result[:urls], PLUGIN_RULE
    refute_includes result[:urls], PLUGIN_RULE_NOTES
    refute_includes result[:urls], "#{PLUGIN_RULES_RAW}/README.md"
  end

  def test_rules_listing_404_skips_rules_and_still_fetches_skills
    result = run_fetch(responses.merge(PLUGIN_RULES => { "status" => 404, "body" => "Not Found" }))

    assert_equal 0, result[:status]
    assert_equal "# recording-studio-gems\n", result[:skills]["recording-studio-gems"]
    assert_empty result[:rules]
    assert_includes result[:stderr], "failed to list rules"
    assert_includes result[:stderr], "skipping"
    assert_includes result[:urls], PLUGIN_SKILL
    assert_includes result[:urls], PLUGIN_RULES
    refute_includes result[:urls], PLUGIN_RULE
  end

  def test_one_rule_fetch_failure_warns_and_still_exits_zero
    result = run_fetch(
      responses.merge(
        PLUGIN_RULES => ok(two_rules_listing_json),
        PLUGIN_RULE => ok("# flatpack-ui\n"),
        PLUGIN_RULE_COPY => { "status" => 404, "body" => "Not Found" }
      )
    )

    assert_equal 0, result[:status]
    assert_equal "# flatpack-ui\n", result[:rules]["flatpack-ui.mdc"]
    refute_includes result[:rules].keys, "user-facing-copy.mdc"
    assert_includes result[:stderr], "failed to fetch user-facing-copy.mdc"
    assert_includes result[:urls], PLUGIN_RULE
    assert_includes result[:urls], PLUGIN_RULE_COPY
  end

  def test_fetched_rules_are_gitignored_untracked_and_not_packaged
    root = File.expand_path("..", __dir__)
    gitignore = File.read(File.join(root, ".gitignore"))

    assert_includes gitignore, ".cursor/rules/"
    assert_includes gitignore, ".cursor/skills/"
    assert_equal "0.2.3", GemTemplate::VERSION

    tracked, status = Open3.capture2("git", "-C", root, "ls-files", "--", ".cursor/rules")
    assert_equal 0, status.exitstatus
    assert_equal "", tracked.strip

    spec = Gem::Specification.load(File.join(root, "gem_template.gemspec"))
    cursor_files = spec.files.select { |path| path == ".cursor" || path.split("/").include?(".cursor") }
    assert_empty cursor_files
  end

  private

  def responses
    {
      PLUGIN_CONTENTS => ok(plugin_listing_json),
      PLUGIN_SKILL => ok("# recording-studio-gems\n")
    }
  end

  def plugin_listing_json
    contents_json(
      { "name" => "recording-studio-gems", "type" => "dir" },
      { "name" => "add-skill-or-agent", "type" => "dir" },
      { "name" => "unrelated-skill", "type" => "dir" },
      { "name" => "README.md", "type" => "file" }
    )
  end

  def extra_listing_json
    contents_json(
      { "name" => "catalog-skill", "type" => "dir" },
      { "name" => "", "type" => "dir" },
      { "name" => "README.md", "type" => "file" }
    )
  end

  def rules_listing_json
    contents_json(
      { "name" => "flatpack-ui.mdc", "type" => "file" },
      { "name" => "notes.md", "type" => "file" },
      { "name" => "nested", "type" => "dir" },
      { "name" => "README.md", "type" => "file" },
      { "name" => "", "type" => "file" }
    )
  end

  def two_rules_listing_json
    contents_json(
      { "name" => "flatpack-ui.mdc", "type" => "file" },
      { "name" => "user-facing-copy.mdc", "type" => "file" }
    )
  end

  def catalog_json
    {
      "sources" => [
        {
          "contents_api" => EXTRA_CONTENTS,
          "raw_base" => EXTRA_RAW_BASE
        }
      ]
    }.to_json
  end

  def contents_json(*items)
    JSON.generate(items)
  end

  def ok(body)
    { "status" => 200, "body" => body }
  end

  def run_fetch(fixtures)
    Dir.mktmpdir { |root| invoke_fetch(root, fixtures) }
  end

  def invoke_fetch(root, fixtures)
    cursor_dir = File.join(root, ".cursor")
    bin_dir = File.join(root, "bin")
    FileUtils.mkdir_p(cursor_dir)
    FileUtils.mkdir_p(bin_dir)
    FileUtils.cp(SCRIPT, File.join(cursor_dir, "fetch-skills.sh"))
    write_fake_curl(bin_dir)

    fixtures_path = File.join(root, "fixtures.json")
    log_path = File.join(root, "curl.log")
    File.write(fixtures_path, JSON.generate(fixtures))
    File.write(log_path, "")

    stdout, stderr, status = Open3.capture3(
      {
        "PATH" => "#{bin_dir}:#{ENV.fetch('PATH')}",
        "FAKE_CURL_FIXTURES" => fixtures_path,
        "FAKE_CURL_LOG" => log_path
      },
      "bash", File.join(cursor_dir, "fetch-skills.sh")
    )

    {
      status: status.exitstatus,
      stdout: stdout,
      stderr: stderr,
      urls: File.read(log_path).split("\n").reject(&:empty?),
      skills: snapshot_skills(File.join(cursor_dir, "skills")),
      rules: snapshot_rules(File.join(cursor_dir, "rules"))
    }
  end

  def snapshot_skills(skills_dir)
    return {} unless File.directory?(skills_dir)

    Dir.children(skills_dir).each_with_object({}) do |skill_id, skills|
      path = File.join(skills_dir, skill_id, "SKILL.md")
      skills[skill_id] = File.read(path) if File.file?(path)
    end
  end

  def snapshot_rules(rules_dir)
    return {} unless File.directory?(rules_dir)

    Dir.children(rules_dir).each_with_object({}) do |name, rules|
      next if name.start_with?(".")
      next unless name.end_with?(".mdc")

      path = File.join(rules_dir, name)
      rules[name] = File.read(path) if File.file?(path)
    end
  end

  def write_fake_curl(bin_dir)
    path = File.join(bin_dir, "curl")
    File.write(path, <<~'PY')
      #!/usr/bin/env python3
      import json
      import os
      import sys

      args = sys.argv[1:]
      out = None
      url = None
      i = 0
      while i < len(args):
          arg = args[i]
          if arg == "-o" and i + 1 < len(args):
              out = args[i + 1]
              i += 2
              continue
          if arg in ("-A", "-H", "--retry", "--retry-delay") and i + 1 < len(args):
              i += 2
              continue
          if arg.startswith("-"):
              i += 1
              continue
          url = arg
          i += 1

      log_path = os.environ["FAKE_CURL_LOG"]
      with open(log_path, "a", encoding="utf-8") as handle:
          handle.write((url or "") + "\n")

      fixtures = json.load(open(os.environ["FAKE_CURL_FIXTURES"], encoding="utf-8"))
      entry = fixtures.get(url)
      if entry is None:
          sys.stderr.write("fake-curl: unstubbed URL %s\n" % (url,))
          sys.exit(22)

      status = int(entry.get("status", 200))
      body = entry.get("body", "")
      if status >= 400:
          sys.exit(22)
      if out:
          with open(out, "w", encoding="utf-8") as handle:
              handle.write(body)
      else:
          sys.stdout.write(body)
    PY
    FileUtils.chmod(0o755, path)
  end
end
