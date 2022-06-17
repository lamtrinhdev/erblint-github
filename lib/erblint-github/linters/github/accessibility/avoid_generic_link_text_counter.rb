# frozen_string_literal: true

require_relative "../../custom_helpers"

module ERBLint
  module Linters
    module GitHub
      module Accessibility
        class AvoidGenericLinkTextCounter < Linter
          include ERBLint::Linters::CustomHelpers
          include LinterRegistry

          BANNED_GENERIC_TEXT = [
            "Read more",
            "Learn more",
            "Click here",
            "More",
            "Link",
            "Here"
          ].freeze
          MESSAGE = "Avoid using generic link text such as #{BANNED_GENERIC_TEXT.join(', ')} which do not make sense in isolation."

          def run(processed_source)
            processed_source.ast.children.each_with_index do |node, index|
              next unless node.methods.include?(:type) && node.type == :text

              text = node.children.join.strip

              # Checks HTML tags
              if banned_text?(text)
                prev_node = processed_source.ast.children[index - 1]
                next_node = processed_source.ast.children[index + 1]

                next unless tag_type?(prev_node) && tag_type?(next_node)

                text_node_tag = BetterHtml::Tree::Tag.from_node(node)
                prev_node_tag = BetterHtml::Tree::Tag.from_node(prev_node)
                next_node_tag = BetterHtml::Tree::Tag.from_node(next_node)

                aria_label = possible_attribute_values(prev_node_tag, "aria-label")
                aria_labelledby = possible_attribute_values(prev_node_tag, "aria-labelledby")

                # Checks if nested between two link tags.
                if link_tag?(prev_node_tag) && link_tag?(next_node_tag) && next_node_tag.closing?
                  # We skip because we cannot reliably check accessible name given aria-labelledby, or an aria-label that is set to a variable
                  # with static code analysis.
                  next if aria_labelledby.present? || (aria_label.present? && aria_label.join.include?("<%="))
                  # We skip because aria-label contains visible text. Relates to Success Criterion 2.5.3: Label in Name
                  next if aria_label.present? && valid_accessible_name?(aria_label.join, text)

                  range = prev_node_tag.loc.begin_pos...text_node_tag.loc.end_pos
                  source_range = processed_source.to_source_range(range)
                  generate_offense_from_source_range(self.class, source_range)
                end
              end

              # Checks Rails link helpers like `link_to`
              erb_node = node.type == :erb ? node : node.descendants(:erb).first
              next unless erb_node

              _, _, code_node = *erb_node
              source = code_node.loc.source
              ruby_node = extract_ruby_node(source)
              send_node = ruby_node&.descendants(:send)&.first
              next unless send_node.methods.include?(:method_name) && send_node.method_name == :link_to

              banned_text = nil

              send_node.child_nodes.each do |child_node|
                banned_text = child_node.children.join if child_node.methods.include?(:type) && child_node.type == :str && banned_text?(child_node.children.join)

                next unless banned_text.present? && child_node.methods.include?(:type) && child_node.type == :hash

                child_node.descendants(:pair).each do |pair_node|
                  next unless pair_node.children.first.type?(:sym)

                  if pair_node.children.first.children.join == "aria"
                    pair_node.children[1].descendants(:sym).each do |sym_node|
                      banned_text = nil if sym_node.children.join == "label" || sym_node.children.join == "labelledby"
                    end
                  end

                  # Skip if `link_to` has `aria-labelledby` or `aria-label` which we cannot be evaluated accurately with ERB lint alone.
                  # ERB lint removes Ruby string interpolation so the `aria-label` for "<%= link_to 'Learn more', "aria-label": "Learn #{@some_variable}" %>" will
                  # be `Learn` which is unreliable so we have to skip entirely unlike with HTML :(
                  banned_text = nil if pair_node.children.first.children.join == "aria-labelledby" || pair_node.children.first.children.join == "aria-label"
                end
              end
              if banned_text.present?
                tag = BetterHtml::Tree::Tag.from_node(code_node)
                generate_offense(self.class, processed_source, tag)
              end
            end
            counter_correct?(processed_source)
          end

          def autocorrect(processed_source, offense)
            return unless offense.context

            lambda do |corrector|
              if processed_source.file_content.include?("erblint:counter #{simple_class_name}")
                # update the counter if exists
                corrector.replace(offense.source_range, offense.context)
              else
                # add comment with counter if none
                corrector.insert_before(processed_source.source_buffer.source_range, "#{offense.context}\n")
              end
            end
          end

          private

          def banned_text?(text)
            BANNED_GENERIC_TEXT.map(&:downcase).include?(text.downcase)
          end

          def valid_accessible_name?(aria_label, text)
            aria_label.start_with?(text)
          end

          # Checks if Ruby node contains `aria-label` or `aria-labelledby`
          def ruby_node_contains_aria_label_attributes?(pair_node)
            pair_node.children.first.children.join == "aria-labelledby" || pair_node.children.first.children.join == "aria-label"
          end

          def extract_ruby_node(source)
            BetterHtml::TestHelper::RubyNode.parse(source)
          rescue ::Parser::SyntaxError
            nil
          end

          def link_tag?(tag_node)
            tag_node.name == "a"
          end

          def tag_type?(node)
            node.methods.include?(:type) && node.type == :tag
          end
        end
      end
    end
  end
end
