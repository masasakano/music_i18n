# coding: utf-8
require 'test_helper'

# Just unit tests for /app/grid/base_grid.rb and /lib/reverse_sql_order.rb
class BaseGridTest < ActiveSupport::TestCase
  include ApplicationHelper # for suppress_ruby270_warnings()

  test "self.scope_with_trans_order" do
    zombies = artists(:artist_zombies)  # Best(Zombies, The). Other-inferior-Trans(TheZombies); n.b., because of the latter this may come before Zedd!
    zedd    = artists(:artist_zedd)     # Best(Zedd)
    assert_equal "Zombies, The", zombies.title, "sanity check"
    assert_equal "Zedd",         zedd.title,    "sanity check2"

    scope = Artist.where(id: zombies.id).or(Artist.where(id: zedd.id))

    scope_direct_order = scope.order(Arel.sql("array_position(array#{[zombies,zedd].map(&:id).inspect}, artists.id)"))
    assert_equal zombies.id, scope_direct_order.first.id  # sanity check

    scope_asc  = BaseGrid.scope_with_trans_order(scope, Artist, "en")
    assert_equal zedd.id,    scope_asc.first.id, 'Wrong: result should be ["Zedd", "Zombies, The"]), but: '+scope_asc.map{|m| Artist.find(m.id).title}.inspect+"; SQL=#{scope_asc.to_sql}"

    scope_desc = BaseGrid.scope_with_trans_order(scope, Artist, "en").reverse_order  # redefined in /lib/reverse_sql_order.rb
    assert_equal zombies.id, scope_desc.first.id, "wrong... SQL=#{scope_desc.to_sql}"
  end

end


