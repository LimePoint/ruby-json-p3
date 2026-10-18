# frozen_string_literal: true

require "test_helper"

class TestRelativeJSONPointer < Minitest::Test
  DOC = {
    "foo" => %w[bar baz biz],
    "highly" => { "nested" => { "objects" => true } }
  }.freeze

  def test_zero_origin
    rel = "0"
    p = JSONP3::Pointer.new("/foo/1")
    r = JSONP3::RelativePointer.new(rel)
    new_pointer = r.to(p)

    assert_equal("baz", new_pointer.resolve(DOC))
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  def test_parent_origin_pointer_index
    rel = "1/0"
    p = JSONP3::Pointer.new("/foo/1")
    r = JSONP3::RelativePointer.new(rel)
    new_pointer = r.to(p)

    assert_equal("bar", new_pointer.resolve(DOC))
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  def test_negative_index_manipulation
    rel = "0-1"
    p = JSONP3::Pointer.new("/foo/1")
    r = JSONP3::RelativePointer.new(rel)
    new_pointer = r.to(p)

    assert_equal("bar", new_pointer.resolve(DOC))
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  def test_grandparent_origin_nested_pointer
    rel = "2/highly/nested/objects"
    p = JSONP3::Pointer.new("/foo/1")
    r = JSONP3::RelativePointer.new(rel)
    new_pointer = r.to(p)

    assert_equal(true, new_pointer.resolve(DOC)) # rubocop:disable Minitest/AssertTruthy
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  def test_zero_origin_index
    rel = "0#"
    p = JSONP3::Pointer.new("/foo/1")
    r = JSONP3::RelativePointer.new(rel)
    new_pointer = r.to(p)

    assert_equal(1, new_pointer.resolve(DOC))
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  def test_zero_origin_offset_index
    rel = "0+1#"
    p = JSONP3::Pointer.new("/foo/1")
    r = JSONP3::RelativePointer.new(rel)
    new_pointer = r.to(p)

    assert_equal(2, new_pointer.resolve(DOC))
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  def test_parent_index
    rel = "1#"
    p = JSONP3::Pointer.new("/foo/1")
    r = JSONP3::RelativePointer.new(rel)
    new_pointer = r.to(p)

    assert_equal("foo", new_pointer.resolve(DOC))
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  def test_same_origin_pointer
    rel = "0/objects"
    p = JSONP3::Pointer.new("/highly/nested")
    r = JSONP3::RelativePointer.new(rel)
    new_pointer = r.to(p)

    assert_equal(true, new_pointer.resolve(DOC)) # rubocop: disable Minitest/AssertTruthy
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  def test_parent_nested_pointer
    rel = "1/nested/objects"
    p = JSONP3::Pointer.new("/highly/nested")
    r = JSONP3::RelativePointer.new(rel)
    new_pointer = r.to(p)

    assert_equal(true, new_pointer.resolve(DOC)) # rubocop: disable Minitest/AssertTruthy
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  def test_parent_nested_pointer_index
    rel = "2/foo/0"
    p = JSONP3::Pointer.new("/highly/nested")
    r = JSONP3::RelativePointer.new(rel)
    new_pointer = r.to(p)

    assert_equal("bar", new_pointer.resolve(DOC))
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  def test_current_key
    rel = "0#"
    p = JSONP3::Pointer.new("/highly/nested")
    r = JSONP3::RelativePointer.new(rel)
    new_pointer = r.to(p)

    assert_equal("nested", new_pointer.resolve(DOC))
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  def test_parent_key
    rel = "1#"
    p = JSONP3::Pointer.new("/highly/nested")
    r = JSONP3::RelativePointer.new(rel)
    new_pointer = r.to(p)

    assert_equal("highly", new_pointer.resolve(DOC))
    assert_equal(p.to(rel).to_s, new_pointer.to_s)
    assert_equal(r.to_s, rel)
  end

  def test_index_resolve_with_parent
    new_pointer = JSONP3::Pointer.new("/foo/1").to("0#")

    assert_equal([%w[bar baz biz], 1], new_pointer.resolve_with_parent(DOC))
  end

  def test_key_resolve_with_parent
    new_pointer = JSONP3::Pointer.new("/highly/nested").to("0#")

    assert_equal([DOC["highly"], "nested"], new_pointer.resolve_with_parent(DOC))
  end

  def test_index_out_of_range
    new_pointer = JSONP3::Pointer.new("/foo/7").to("0#")

    assert_equal(JSONP3::Pointer::UNDEFINED, new_pointer.resolve(DOC))
  end

  def test_offset_index_out_of_range
    new_pointer = JSONP3::Pointer.new("/foo/1").to("0+5#")

    assert_equal(JSONP3::Pointer::UNDEFINED, new_pointer.resolve(DOC))
  end

  def test_offset_to_last_index
    new_pointer = JSONP3::Pointer.new("/foo/0").to("0+2#")

    assert_equal(2, new_pointer.resolve(DOC))
  end

  NUMERIC_KEYS = { "o" => { "1" => { "x" => "a" }, "2" => { "x" => "b" } } }.freeze

  def test_offset_member_index
    new_pointer = JSONP3::Pointer.new("/o/1").to("0+1#")

    assert_equal(JSONP3::Pointer::UNDEFINED, new_pointer.resolve(NUMERIC_KEYS))
  end

  def test_offset_member
    new_pointer = JSONP3::Pointer.new("/o/1").to("0+1")

    assert_equal(JSONP3::Pointer::UNDEFINED, new_pointer.resolve(NUMERIC_KEYS))
  end

  def test_offset_member_pointer
    new_pointer = JSONP3::Pointer.new("/o/1/x").to("1+1/x")

    assert_equal(JSONP3::Pointer::UNDEFINED, new_pointer.resolve(NUMERIC_KEYS))
  end

  def test_offset_member_resolve_with_parent
    new_pointer = JSONP3::Pointer.new("/o/1").to("0+1")

    undefined = JSONP3::Pointer::UNDEFINED

    assert_equal([undefined, undefined], new_pointer.resolve_with_parent(NUMERIC_KEYS))
  end

  def test_offset_item_pointer
    new_pointer = JSONP3::Pointer.new("/0/x").to("1+1/x")

    assert_equal("b", new_pointer.resolve([{ "x" => "a" }, { "x" => "b" }]))
  end

  def test_offset_item_resolve_with_parent
    new_pointer = JSONP3::Pointer.new("/foo/1").to("0+1")

    assert_equal([%w[bar baz biz], "biz"], new_pointer.resolve_with_parent(DOC))
  end

  def test_offset_named_member
    error = assert_raises(JSONP3::Pointer::IndexError) { JSONP3::Pointer.new("/highly/nested").to("0+1") }
    assert_equal("an index offset can only be applied to an array item", error.message)
  end

  def test_offset_root
    assert_raises(JSONP3::Pointer::IndexError) { JSONP3::Pointer.new("/foo").to("1+1") }
  end

  def test_parent_index_of_root
    error = assert_raises(JSONP3::Pointer::IndexError) { JSONP3::Pointer.new("/foo").to("1#") }
    assert_equal("the document root has no member name or array index", error.message)
  end

  def test_index_of_root
    assert_raises(JSONP3::Pointer::IndexError) { JSONP3::Pointer.new("").to("0#") }
  end
end
