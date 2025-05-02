# coding: utf-8
require "test_helper"

class ModuleWasFoundTest < ActiveSupport::TestCase
  class MyTestModuleWasFound
    include ModuleWasFound
    define_was_found_for("group")

    def this_was_found(found, created, run: :found)
      self.was_found   = found
      self.was_created = created

      case run
      when :found
        was_found?
      when :created
        was_created?
      else
        raise ArgumentError, 'wrong arg'
      end
    end

    def this_group_found(found, created, run: :found)
      self.group_found   = found
      self.group_created = created

      case run
      when :found
        group_found?
      when :created
        group_created?
      else
        raise ArgumentError, 'wrong arg'
      end
    end
  end

  test "was_found/created?" do
    obj = MyTestModuleWasFound.new
    %i(found created).each do |metho|
      assert_raises(HaramiMusicI18n::ModuleWasFounds::InconsistencyInWasFoundError){
        obj.this_was_found(nil, nil,     run: metho) }
      assert_raises(HaramiMusicI18n::ModuleWasFounds::InconsistencyInWasFoundError){
        obj.this_was_found(false, false, run: metho) }
      assert_raises(HaramiMusicI18n::ModuleWasFounds::InconsistencyInWasFoundError, "failed in #{metho.inspect}"){
        obj.this_was_found("ab", "cd",   run: metho) }
    end

    assert_raises(ArgumentError, "failed in set_was_found_if_true"){
      obj.send(:set_was_found_if_true) }

    assert obj.this_was_found("a", nil, run: :found)
    refute obj.this_was_found(nil, "a", run: :found)
    assert obj.this_was_found(nil, "a", run: :created)
    refute obj.this_was_found("a", nil, run: :created)

    ## Tests of set_was_found_true
    obj = MyTestModuleWasFound.new
    obj.set_was_found_true
    assert obj.was_found?
    refute obj.was_created?

    obj.was_found = nil
    obj.set_was_created_true
    assert obj.was_created?
    refute obj.was_found?

    ## Tests of set_was_found_if_true
    obj.reset_was_found_created
    obj.set_was_found_if_true(true)
    assert obj.was_found?

    obj.reset_was_found_created
    obj.set_was_found_if_true(false)
    refute obj.was_found?

    obj.reset_was_found_created
    obj.set_was_found_if_true{ true }
    assert obj.was_found?

    obj.reset_was_found_created
    obj.set_was_found_if_true{ false }
    refute obj.was_found?
  end

  test "group_found/created?" do
    obj = MyTestModuleWasFound.new
    %i(found created).each do |metho|
      assert_raises(HaramiMusicI18n::ModuleWasFounds::InconsistencyInWasFoundError){
        obj.this_group_found(nil, nil,     run: metho) }
      assert_raises(HaramiMusicI18n::ModuleWasFounds::InconsistencyInWasFoundError){
        obj.this_group_found(false, false, run: metho) }
      assert_raises(HaramiMusicI18n::ModuleWasFounds::InconsistencyInWasFoundError, "failed in #{metho.inspect}"){
        obj.this_group_found("ab", "cd",   run: metho) }
    end

    assert_raises(ArgumentError, "failed in set_group_found_if_true with no Arguments"){
      obj.send(:set_group_found_if_true) }

    assert obj.this_group_found("a", nil, run: :found)
    refute obj.this_group_found(nil, "a", run: :found)
    assert obj.this_group_found(nil, "a", run: :created)
    refute obj.this_group_found("a", nil, run: :created)

    obj = MyTestModuleWasFound.new
    obj.set_group_found_true
    assert obj.group_found?
    refute obj.group_created?

    obj.group_found = nil
    obj.set_group_created_true
    assert obj.group_created?
    refute obj.group_found?

    ## Tests of set_group_found_if_true
    obj.reset_group_found_created
    obj.set_group_found_if_true(true)
    assert obj.group_found?

    obj.reset_group_found_created
    obj.set_group_found_if_true(false)
    refute obj.group_found?

    obj.reset_group_found_created
    obj.set_group_found_if_true{ true }
    assert obj.group_found?

    obj.reset_group_found_created
    obj.set_group_found_if_true{ false }
    refute obj.group_found?
  end

end
