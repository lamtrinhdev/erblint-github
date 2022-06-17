# frozen_string_literal: true

require "test_helper"

class AvoidGenericLinkTextCounterTest < LinterTestCase
  def linter_class
    ERBLint::Linters::GitHub::Accessibility::AvoidGenericLinkTextCounter
  end

  def test_warns_when_link_text_is_click_here
    @file = "<a>Click here</a>"
    @linter.run(processed_source)

    refute_empty @linter.offenses
  end

  def test_warns_when_link_text_is_learn_more
    @file = "<a>Learn more</a>"
    @linter.run(processed_source)

    refute_empty @linter.offenses
  end

  def test_warns_when_link_text_is_read_more
    @file = "<a>Read more</a>"
    @linter.run(processed_source)

    refute_empty @linter.offenses
  end

  def test_warns_when_link_text_is_more
    @file = "<a>More</a>"
    @linter.run(processed_source)

    refute_empty @linter.offenses
  end

  def test_warns_when_link_text_is_link
    @file = "<a>Link</a>"
    @linter.run(processed_source)

    refute_empty @linter.offenses
  end

  def test_does_not_warn_when_banned_text_is_part_of_more_text
    @file = "<a>Learn more about GitHub Stars</a>"
    @linter.run(processed_source)

    assert_empty @linter.offenses
  end

  def test_ignores_when_aria_label_with_variable_is_set_on_link_tag
    @file = <<~ERB
      <a aria-label="<%= tooltip_text %>">Learn more</a>
    ERB
    @linter.run(processed_source)

    assert_empty @linter.offenses
  end

  def test_flags_when_aria_label_does_not_include_visible_link_text
    @file = <<~ERB
      <a aria-label="GitHub Sponsors">Learn more</a>
    ERB
    @linter.run(processed_source)

    refute_empty @linter.offenses
  end

  def test_does_not_flag_when_aria_label_includes_visible_link_text
    @file = <<~ERB
      <a aria-label="Learn more about GitHub Sponsors">Learn more</a>
    ERB
    @linter.run(processed_source)

    assert_empty @linter.offenses
  end

  def test_ignores_when_aria_labelledby_is_set_on_link_tag
    @file = "<a aria-labelledby='someElement'>Click here</a>"
    @linter.run(processed_source)

    assert_empty @linter.offenses
  end

  def test_warns_when_link_rails_helper_text_is_banned_text
    @file = "<%= link_to('click here', redirect_url, id: 'redirect') %>"
    @linter.run(processed_source)

    refute_empty @linter.offenses
  end

  def test_ignores_when_link_rails_helper_text_is_banned_text_with_aria_labelled_by
    @file = "<%= link_to('learn more', 'aria-labelledby': 'element1234', id: 'redirect') %>"
    @linter.run(processed_source)

    assert_empty @linter.offenses
  end

  def test_ignores_when_link_rails_helper_text_is_banned_text_with_aria_label_that_cannot_be_parsed_by_linter
    @file = <<~ERB
      <%= link_to('learn more', 'aria-label': some_variable, id: 'redirect') %>
    ERB
    @linter.run(processed_source)

    assert_empty @linter.offenses
  end

  def test_ignores_when_link_rails_helper_text_is_banned_text_with_aria_label_since_cannot_be_parsed_accurately_by_linter
    @file = <<~ERB
      <%= link_to('learn more', 'aria-label': "Learn #{@variable}", id: 'redirect') %>
    ERB
    @linter.run(processed_source)

    assert_empty @linter.offenses
  end

  def test_ignores_when_link_rails_helper_text_is_banned_text_with_aria_label
    @file = "<%= link_to('learn more', 'aria-label': 'learn more about GitHub', id: 'redirect') %>"
    @linter.run(processed_source)

    assert_empty @linter.offenses
  end

  def test_ignores_when_link_rails_helper_text_is_banned_text_with_aria_label_hash
    @file = "<%= link_to('learn more', aria: { label: 'learn more about GitHub' }, id: 'redirect') %>"
    @linter.run(processed_source)

    assert_empty @linter.offenses
  end

  def test_does_not_warn_when_generic_text_is_link_rails_helper_sub_text
    @file = "<%= link_to('click here to learn about github', redirect_url, id: 'redirect') %>"
    @linter.run(processed_source)

    assert_empty @linter.offenses
  end

  def test_does_not_warns_if_element_has_correct_counter_comment
    @file = <<~ERB
      <%# erblint:counter GitHub::Accessibility::AvoidGenericLinkTextCounter 1 %>
      <a>Link</a>
    ERB
    @linter.run(processed_source)

    assert_equal 0, @linter.offenses.count
  end

  def test_autocorrects_when_ignores_are_not_correct
    @file = <<~ERB
      <%# erblint:counter GitHub::Accessibility::AvoidGenericLinkTextCounter 2 %>
      <a>Link</a>
    ERB
    refute_equal @file, corrected_content

    expected_content = <<~ERB
      <%# erblint:counter GitHub::Accessibility::AvoidGenericLinkTextCounter 1 %>
      <a>Link</a>
    ERB
    assert_equal expected_content, corrected_content
  end
end
