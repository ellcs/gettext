# -*- coding: utf-8 -*-
#
# Copyright (C) 2012  Kouhei Sutou <kou@clear-code.com>
# Copyright (C) 2012  Haruka Yoshihara <yoshihara@clear-code.com>
#
# License: Ruby's or LGPL
#
# This library is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "gettext/tools/poparser"

class TestPoParser < Test::Unit::TestCase
  def test_msgstr_not_existing
    po_file = create_po_file(<<-EOP)
msgid "Hello"
msgstr ""
EOP
    messages = parse_po_file(po_file, MoFile.new)

    assert_equal(nil, messages["Hello"])
  end

  def test_empty_msgstr_for_msgid_plural
    po_file = create_po_file(<<-EOP)
msgid "He"
msgid_plural "They"
msgstr[0] ""
msgstr[1] ""
EOP
    messages = parse_po_file(po_file, MoFile.new)

    assert_true(messages.has_key?("He\000They"))
    assert_equal(nil, messages["He\000They"])
  end

  class TestPoEntries < self
    def test_msgstr
      po_file = create_po_file(<<-EOP)
# This is the comment.
#: file.rb:10
msgid "hello"
msgstr "bonjour"
EOP
      entries = parse_po_file(po_file, PoEntries.new)
      assert_true(entries.has_key?("hello"))
      assert_equal("bonjour", entries["hello"].msgstr)
    end

    def test_sources
      po_file = create_po_file(<<-EOP)
# This is the comment.
#: file.rb:10
msgid "hello"
msgstr "bonjour"
EOP
      entries = parse_po_file(po_file, PoEntries.new)
      assert_true(entries.has_key?("hello"))
      assert_equal(["file.rb:10"], entries["hello"].sources)
    end

    def test_comment
      po_file = create_po_file(<<-EOP)
# This is the comment.
#: file.rb:10
msgid "hello"
msgstr "bonjour"
EOP
      entries = parse_po_file(po_file, PoEntries.new)
      assert_true(entries.has_key?("hello"))
      assert_equal("This is the comment.", entries["hello"].comment)
    end
  end

  private
  def create_po_file(content)
    po_file = Tempfile.new("hello.po")
    po_file.print(content)
    po_file.close
    po_file
  end

  def parse_po_file(po_file, parsed_entries)
    parser = GetText::PoParser.new
    parser.parse_file(po_file.path, parsed_entries)
  end

  class FuzzyTest < self
    def setup
      @po = <<-EOP
#, fuzzy
msgid "Hello"
msgstr "Bonjour"
EOP
      @po_file = Tempfile.new("hello.po")
      @po_file.print(@po)
      @po_file.close
    end

    class IgnoreTest < self
      def test_report_warning
        mock($stderr).print("Warning: fuzzy message was ignored.\n")
        mock($stderr).print("  #{@po_file.path}: msgid 'Hello'\n")
        messages = parse do |parser|
          parser.ignore_fuzzy = true
          parser.report_warning = true
        end
        assert_nil(messages["Hello"])
      end

      def test_not_report_warning
        dont_allow($stderr).print("Warning: fuzzy message was ignored.\n")
        dont_allow($stderr).print("  #{@po_file.path}: msgid 'Hello'\n")
        messages = parse do |parser|
          parser.ignore_fuzzy = true
          parser.report_warning = false
        end
        assert_nil(messages["Hello"])
      end
    end

    class NotIgnore < self
      def test_report_warning
        mock($stderr).print("Warning: fuzzy message was used.\n")
        mock($stderr).print("  #{@po_file.path}: msgid 'Hello'\n")
        messages = parse do |parser|
          parser.ignore_fuzzy = false
          parser.report_warning = true
        end
        assert_equal("Bonjour", messages["Hello"])
      end

      def test_not_report_warning
        dont_allow($stderr).print("Warning: fuzzy message was used.\n")
        dont_allow($stderr).print("  #{@po_file.path}: msgid 'Hello'\n")
        messages = parse do |parser|
          parser.ignore_fuzzy = false
          parser.report_warning = false
        end
        assert_equal("Bonjour", messages["Hello"])
      end
    end

    private
    def parse
      parser = GetText::PoParser.new
      class << parser
        def _(message_id)
          message_id
        end
      end
      messages = MoFile.new
      yield parser
      parser.parse_file(@po_file.path, messages)
      messages
    end
  end
end
