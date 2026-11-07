-- The rules for comments on a profile. The server stores them; see ProfileComments.
local Comments = {
	MAX_LENGTH = 140,
	MAX_KEPT = 50,
	COOLDOWN = 10, -- seconds between posts
}

-- Returns the text to post, or nil if it can't be posted.
function Comments.clean(raw: any): string?
	if type(raw) ~= "string" or not utf8.len(raw) then
		return nil
	end
	local text = string.gsub(string.gsub(raw, "[\r\n\t]", " "), "^%s*(.-)%s*$", "%1")
	local length = utf8.len(text)
	if not length or length == 0 or length > Comments.MAX_LENGTH then
		return nil
	end
	return text
end

function Comments.find(list: { any }, authorId: number): any?
	for _, comment in list do
		if comment.authorId == authorId then
			return comment
		end
	end
	return nil
end

function Comments.remove(list: { any }, authorId: number): boolean
	for index, comment in list do
		if comment.authorId == authorId then
			table.remove(list, index)
			return true
		end
	end
	return false
end

-- Adds a comment at the top, replacing that author's last one.
function Comments.put(list: { any }, comment: any): { any }
	Comments.remove(list, comment.authorId)
	table.insert(list, 1, comment)
	while #list > Comments.MAX_KEPT do
		table.remove(list)
	end
	return list
end

function Comments.canPost(authorId: number, ownerId: number, commentsOff: boolean): (boolean, string?)
	if authorId == ownerId then
		return false, "OwnProfile"
	elseif commentsOff then
		return false, "CommentsOff"
	end
	return true, nil
end

function Comments.cooled(lastAt: number?, now: number): boolean
	return lastAt == nil or now - lastAt >= Comments.COOLDOWN
end

return Comments
