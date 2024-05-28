defmodule Hologram.UI.LinkTest do
  use Hologram.Test.ComponentCase, async: false

  alias Hologram.Test.Fixtures.UI.Link.Module1
  alias Hologram.Test.Fixtures.UI.Link.Module2
  alias Hologram.UI.Link

  test "with text anchor" do
    assert render_markup(~H"<Link to={Module1}>my anchor text</Link>") ==
             ~s'<a href="/hologram-test-fixtures-ui-link-module1">my anchor text</a>'
  end

  test "with non-text anchor" do
    assert render_markup(~H"<Link to={Module1}><div>my anchor text</div></Link>") ==
             ~s'<a href="/hologram-test-fixtures-ui-link-module1"><div>my anchor text</div></a>'
  end

  test "with page params" do
    assert render_markup(~H"<Link to={Module2, abc: 123, xyz: 987}>my anchor text</Link>") ==
             ~s'<a href="/hologram-test-fixtures-ui-link-module2/123/987">my anchor text</a>'
  end
end
