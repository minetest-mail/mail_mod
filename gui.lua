selected_message_idxs = {}

local theme
if minetest.get_modpath("default") then
	theme = default.gui_bg .. default.gui_bg_img
else
	theme = ""
end

mail.inbox_formspec = "size[8,9;]" .. theme .. [[
		button_exit[7.25,0;0.75,0.5;quit;X]
		button[6,1;2,0.5;new;New Message]
		button[6,2;2,0.5;read;Read]
		button[6,3;2,0.5;reply;Reply]
		button[6,3.8;2,0.5;replyall;Reply All]
		button[6,4.6;2,0.5;forward;Forward]
		button[6,5.6;2,0.5;markread;Mark Read]
		button[6,6.4;2,0.5;markunread;Mark Unread]
		button[6,7.4;2,0.5;delete;Delete]
		button[6,8.4;2,0.5;about;About]
		tablecolumns[color;text;text]
		table[0,0;5.75,9;messages;#999,From,Subject]]


function mail.show_about(name)
	local formspec = [[
			size[8,5;]
			button[7.25,0;0.75,0.5;back;X]
			label[0,0;Mail]
			label[0,0.5;By cheapie]
			label[0,1;http://github.com/cheapie/mail]
			label[0,1.5;See LICENSE file for license information]
			label[0,2.5;NOTE: Communication using this system]
			label[0,3;is NOT guaranteed to be private!]
			label[0,3.5;Admins are able to view the messages]
			label[0,4;of any player.]
		]] .. theme

	minetest.show_formspec(name, "mail:about", formspec)
end

function mail.show_inbox(name)
	local formspec = { mail.inbox_formspec }
	local messages = mail.getMessages(name)

	if messages[1] then
		for _, message in ipairs(messages) do
			mail.ensure_new_format(message)
			if message.unread then
				if not mail.player_in_list(name, message.to) then
					formspec[#formspec + 1] = ",#FFD788"
				else
					formspec[#formspec + 1] = ",#FFD700"
				end
			else
				if not mail.player_in_list(name, message.to) then
					formspec[#formspec + 1] = ",#CCCCDD"
				else
					formspec[#formspec + 1] = ","
				end
			end
			formspec[#formspec + 1] = ","
			formspec[#formspec + 1] = minetest.formspec_escape(message.from)
			formspec[#formspec + 1] = ","
			if message.subject ~= "" then
				if string.len(message.subject) > 30 then
					formspec[#formspec + 1] =
							minetest.formspec_escape(string.sub(message.subject, 1, 27))
					formspec[#formspec + 1] = "..."
				else
					formspec[#formspec + 1] = minetest.formspec_escape(message.subject)
				end
			else
				formspec[#formspec + 1] = "(No subject)"
			end
		end
		if selected_message_idxs[name] then
			formspec[#formspec + 1] = ";"
			formspec[#formspec + 1] = tostring(selected_message_idxs[name] + 1)
		end
		formspec[#formspec + 1] = "]"
	else
		formspec[#formspec + 1] = "]label[2,4.5;No mail]"
	end
	minetest.show_formspec(name, "mail:inbox", table.concat(formspec, ""))
end

function mail.show_message(name, msgnumber)
	local messages = mail.getMessages(name)
	local message = messages[msgnumber]
	local formspec = [[
			size[8,9]
			button[7.25,0;0.75,0.5;back;X]
			label[0,0;From: %s]
			label[0,0.4;To: %s]
			label[0,0.8;CC: %s]
			label[0,1.3;Subject: %s]
			textarea[0.25,1.8;8,7.8;body;;%s]
			button[0,8.5;2,1;reply;Reply]
			button[2,8.5;2,1;replyall;Reply All]
			button[4,8.5;2,1;forward;Forward]
			button[6,8.5;2,1;delete;Delete]
		]] .. theme

	local from = minetest.formspec_escape(message.from)
	local to = minetest.formspec_escape(message.to)
	local cc = minetest.formspec_escape(message.cc)
	local subject = minetest.formspec_escape(message.subject)
	local body = minetest.formspec_escape(message.body)
	formspec = string.format(formspec, from, to, cc, subject, body)

	minetest.show_formspec(name,"mail:message",formspec)
end

function mail.show_compose(name, defaultto, defaultsubj, defaultbody, defaultcc, defaultbcc)
	local formspec = [[
			size[8,9]
			field[0.25,0.5;3.5,1;to;To:;%s]
			field[3.75,0.5;3.75,1;cc;CC:;%s]
			field[3.75,1.6;3.75,1;bcc;BCC:;%s]
			field[0.25,2.5;8,1;subject;Subject:;%s]
			textarea[0.25,3.2;8,6;body;;%s]
			button[0.5,8.5;3,1;cancel;Cancel]
			button[7.25,0;0.75,0.5;cancel;X]
			button[4.5,8.5;3,1;send;Send]
		]] .. theme

	defaultto = defaultto or ""
	defaultsubj = defaultsubj or ""
	defaultbody = defaultbody or ""
	defaultcc = defaultcc or ""
	defaultbcc = defaultbcc or ""

	formspec = string.format(formspec,
		minetest.formspec_escape(defaultto),
		minetest.formspec_escape(defaultcc),
		minetest.formspec_escape(defaultbcc),
		minetest.formspec_escape(defaultsubj),
		minetest.formspec_escape(defaultbody))

	minetest.show_formspec(name, "mail:compose", formspec)
end

function mail.reply(name, message)
	mail.ensure_new_format(message)
	local replyfooter = "Type your reply here.\n\n--Original message follows--\n" ..message.body
	mail.show_compose(name, message.from, "Re: "..message.subject, replyfooter)
end

function mail.replyall(name, message)
	mail.ensure_new_format(message)
	local replyfooter = "Type your reply here.\n\n--Original message follows--\n" ..message.body
	-- new recipients are the sender plus the original recipients, minus ourselves
	local recipients = message.to
	if message.from ~= nil then
		recipients = message.from .. ", " .. recipients
	end
	print('parsing recipients:   '..recipients)
	recipients = mail.parse_player_list(recipients)
	for k,v in pairs(recipients) do
		if v == name then
			table.remove(recipients, k)
			break
		end
	end
	recipients = mail.concat_player_list(recipients)
	print('resulting recipients: '..recipients)
	mail.show_compose(name, recipients, "Re: "..message.subject, replyfooter, message.cc)
end

function mail.forward(name, message)
	local fwfooter = "Type your message here.\n\n--Original message follows--\n" ..message.body
	mail.show_compose(name, "", "Fw: "..message.subject, fwfooter)
end

function mail.handle_receivefields(player, formname, fields)
	if formname == "" and fields and fields.quit and minetest.get_modpath("unified_inventory") then
		unified_inventory.set_inventory_formspec(player, "craft")
	end

	if formname == "mail:about" then
		minetest.after(0.5, function()
			mail.show_inbox(player:get_player_name())
		end)

	elseif formname == "mail:inbox" then
		local name = player:get_player_name()
		local messages = mail.getMessages(name)

		if fields.messages then
			local evt = minetest.explode_table_event(fields.messages)
			selected_message_idxs[name] = evt.row - 1
			if evt.type == "DCL" and messages[selected_message_idxs[name]] then
				messages[selected_message_idxs[name]].unread = false
				mail.show_message(name, selected_message_idxs[name])
			end
			mail.setMessages(name, messages)
			return true
		end
		if fields.read then
			if messages[selected_message_idxs[name]] then
				messages[selected_message_idxs[name]].unread = false
				mail.show_message(name, selected_message_idxs[name])
			end

		elseif fields.delete then
			if messages[selected_message_idxs[name]] then
				table.remove(messages, selected_message_idxs[name])
			end

			mail.show_inbox(name)
		elseif fields.reply and messages[selected_message_idxs[name]] then
			local message = messages[selected_message_idxs[name]]
			mail.reply(name, message)
		
		elseif fields.replyall and messages[selected_message_idxs[name]] then
			local message = messages[selected_message_idxs[name]]
			mail.replyall(name, message)

		elseif fields.forward and messages[selected_message_idxs[name]] then
			local message = messages[selected_message_idxs[name]]
			mail.forward(name, message)

		elseif fields.markread then
			if messages[selected_message_idxs[name]] then
				messages[selected_message_idxs[name]].unread = false
			end
			-- set messages immediately, so it shows up already when updating the inbox
			mail.setMessages(name, messages)
			mail.show_inbox(name)
			return true

		elseif fields.markunread then
			if messages[selected_message_idxs[name]] then
				messages[selected_message_idxs[name]].unread = true
			end
			-- set messages immediately, so it shows up already when updating the inbox
			mail.setMessages(name, messages)
			mail.show_inbox(name)
			return true

		elseif fields.new then
			mail.show_compose(name)

		elseif fields.quit then
			if minetest.get_modpath("unified_inventory") then
				unified_inventory.set_inventory_formspec(player, "craft")
			end

		elseif fields.about then
			mail.show_about(name)

		end

		mail.setMessages(name, messages)
		return true
	elseif formname == "mail:message" then
		local name = player:get_player_name()
		local messages = mail.getMessages(name)

		if fields.back then
			mail.show_inbox(name)
			return true	-- don't uselessly set messages
		elseif fields.reply then
			local message = messages[selected_message_idxs[name]]
			mail.reply(name, message)
		elseif fields.replyall then
			local message = messages[selected_message_idxs[name]]
			mail.replyall(name, message)
		elseif fields.forward then
			local message = messages[selected_message_idxs[name]]
			mail.forward(name, message.subject)
		elseif fields.delete then
			if messages[selected_message_idxs[name]] then
				table.remove(messages,selected_message_idxs[name])
			end
			mail.show_inbox(name)
		end

		mail.setMessages(name, messages)
		return true
	elseif formname == "mail:compose" then
		if fields.send then
			mail.send({
				from = player:get_player_name(),
				to = fields.to,
				cc = fields.cc,
				bcc = fields.bcc,
				subject = fields.subject,
				body = fields.body,
			})
		end
		minetest.after(0.5, function()
			mail.show_inbox(player:get_player_name())
		end)
		return true

	elseif fields.mail then
		mail.show_inbox(player:get_player_name())
	else
		return false
	end
end

minetest.register_on_player_receive_fields(mail.handle_receivefields)


if minetest.get_modpath("unified_inventory") then
	mail.receive_mail_message = mail.receive_mail_message ..
		" or use the mail button in the inventory"
	mail.read_later_message = mail.read_later_message ..
		" or by using the mail button in the inventory"

	unified_inventory.register_button("mail", {
			type = "image",
			image = "mail_button.png",
			tooltip = "Mail"
		})
end
