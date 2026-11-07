local harness = require("./harness")
local Comments = require("../src/shared/CardCore/Comments")

local describe, it, expect = harness.describe, harness.it, harness.expect

local function comment(authorId: number, text: string?): any
	return { authorId = authorId, authorName = "A", text = text or "hi", at = 0 }
end

describe("Comments", function()
	it("trims text and joins lines", function()
		expect(Comments.clean("  hello\n there  ")).toBe("hello  there")
	end)

	it("refuses empty, long or non-text comments", function()
		expect(Comments.clean("   ")).toBe(nil)
		expect(Comments.clean(string.rep("a", Comments.MAX_LENGTH + 1))).toBe(nil)
		expect(Comments.clean(5)).toBe(nil)
		expect(Comments.clean(string.char(255, 254))).toBe(nil)
	end)

	it("takes a comment of exactly the longest length", function()
		local text = string.rep("a", Comments.MAX_LENGTH)
		expect(Comments.clean(text)).toBe(text)
	end)

	it("puts the newest comment first", function()
		local list = Comments.put({ comment(1) }, comment(2))
		expect(list[1].authorId).toBe(2)
		expect(#list).toBe(2)
	end)

	it("replaces a comment from the same player", function()
		local list = Comments.put({ comment(1, "old"), comment(2) }, comment(2, "new"))
		expect(#list).toBe(2)
		expect(list[1].text).toBe("new")
		expect(#Comments.put(list, comment(1, "edit"))).toBe(2)
	end)

	it("keeps only the newest comments", function()
		local list = {}
		for id = 1, Comments.MAX_KEPT + 3 do
			list = Comments.put(list, comment(id))
		end
		expect(#list).toBe(Comments.MAX_KEPT)
		expect(list[1].authorId).toBe(Comments.MAX_KEPT + 3)
		expect(Comments.find(list, 1)).toBe(nil)
	end)

	it("removes a comment by its author", function()
		local list = { comment(1), comment(2) }
		expect(Comments.remove(list, 1)).toBe(true)
		expect(#list).toBe(1)
		expect(Comments.remove(list, 9)).toBe(false)
	end)

	it("stops comments on your own profile or a closed one", function()
		expect(Comments.canPost(1, 2, false)).toBe(true)
		local own, ownCode = Comments.canPost(1, 1, false)
		expect(own).toBe(false)
		expect(ownCode).toBe("OwnProfile")
		local off, offCode = Comments.canPost(1, 2, true)
		expect(off).toBe(false)
		expect(offCode).toBe("CommentsOff")
	end)

	it("waits between posts", function()
		expect(Comments.cooled(nil, 100)).toBe(true)
		expect(Comments.cooled(100, 100 + Comments.COOLDOWN - 1)).toBe(false)
		expect(Comments.cooled(100, 100 + Comments.COOLDOWN)).toBe(true)
	end)
end)
