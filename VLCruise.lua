--[[
VLCruise Extension for VLC media player 2.0
Authors: Sky Morey

The MIT License (MIT)

Copyright (c) 2015 BclEx

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

--[[ Global var ]]--

-- You can set here your default language by replacing nil with
-- your language code (see below).Example:
-- language = "fre",
-- language = "ger",
-- language = "eng",
-- ...

local options = {
	language = nil,
	downloadBehaviour = 'save',
	langExt = false,
	removeTag = false,
	showMediaInformation = true,
	progressBarSize = 80,
	intLang = 'eng',
	translations_avail =
	{
		eng = 'English'
	},
	translation =
	{
		int_all = 'All',
		int_descr = 'Download subtitles from OpenSubtitles.org',
		int_research = 'Research',
		int_config = 'Config',
		int_configuration = 'Configuration',
		int_help = 'Help',
		int_search_hash = 'Search by hash',
		int_search_name = 'Search by name',
		int_title = 'Title',
		int_season = 'Season (series)',
		int_episode = 'Episode (series)',
		int_show_help = 'Show help',
		int_show_conf = 'Show config',
		int_dowload_sel = 'Download selection',
		int_close = 'Close',
		int_ok = 'Ok',
		int_save = 'Save',
		int_cancel = 'Cancel',
		int_bool_true = 'Yes',
		int_bool_false = 'No',
		int_search_transl = 'Search translations',
		int_searching_transl = 'Searching translations ...',
		int_int_lang = 'Interface language',
		int_default_lang = 'Subtitles language',
		int_dowload_behav = 'What to do with subtitles',
		int_dowload_save = 'Load and save',
		int_dowload_load = 'Load only',
		int_dowload_manual = 'Manual download',
		int_display_code = 'Display language code in file name',
		int_remove_tag = 'Remove tags',
		int_vlsub_work_dir = 'cruise working directory',
		int_os_username = 'Username',
		int_os_password = 'Password',
		int_help_mess = [[
				    HELP
				    ]],
		int_no_support_mess = [[
					NO SUPPORT
				    ]],

		action_login = 'Logging in',
		action_logout = 'Logging out',
		action_noop = 'Checking session',
		action_search = 'Searching subtitles',
		action_hash = 'Calculating movie hash',

		mess_success = 'Success',
		mess_error = 'Error',
		mess_no_response = 'Server not responding',
		mess_unauthorized = 'Request unauthorized',
		mess_expired = 'Session expired, retrying',
		mess_overloaded = 'Server overloaded, please retry later',
		mess_no_input = 'Please use this method during playing',
		mess_not_local = 'This method works with local file only (for now)',
		mess_not_found = 'File not found',
		mess_not_found2 = 'File not found (illegal character?)',
		mess_no_selection = 'No subtitles selected',
		mess_save_fail = 'Unable to save subtitles',
		mess_click_link = 'Click here to open the file',
		mess_complete = 'Research complete',
		mess_no_res = 'No result',
		mess_res = 'result(s)',
		mess_loaded = 'Subtitles loaded',
		mess_not_load = 'Unable to load subtitles',
		mess_downloading = 'Downloading subtitle',
		mess_dowload_link = 'Download link',
		mess_err_conf_access = 'Can\'t find a suitable path to save config, please set it manually',
		mess_err_wrong_path = 'the path contains illegal character, please correct it'
	}
}

local languages = {
	{ 'eng', 'English' }
}

-- Languages code conversion table: iso-639-1 to iso-639-3
-- See https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
local lang_os_to_iso = {
	en = "eng"
}

local dlg = nil
local input_table = { } -- General widget id reference
local select_conf = { } -- Drop down widget / option table association 

--[[ VLC extension stuff ]]--
function descriptor()
	return {
		title = "VLCruise 0.0.1",
		version = "0.0.1",
		author = "bclex",
		url = 'http://www.opencruise.org/',
		shortdesc = "VLCruise";
		description = options.translation.int_descr,
		capabilities = { "menu", "input-listener" }
	}
end

function activate()
	vlc.msg.dbg("[cruise] Begin")
	if not check_config() then
		vlc.msg.err("[cruise] Unsupported VLC version")
		return false
	end

	if vlc.input.item() then
		cruise.getFileInfo()
		cruise.getMovieInfo()
	end

	show_main()
end

function close()
	vlc.deactivate()
end

function deactivate()
	vlc.msg.dbg("[cruise] End")
	if dlg then
		dlg:hide()
	end

	if cruise.session.token and cruise.session.token ~= "" then
		cruise.request("LogOut")
	end
end

function menu()
	return {
		lang.int_research,
		lang.int_config,
		lang.int_help
	}
end

function meta_changed()
	return false
end

function input_changed()
	collectgarbage()
	set_interface_main()
	collectgarbage()
end

--[[ Interface data ]]--
function interface_main()
	dlg:add_label(lang["int_default_lang"] .. ':', 1, 1, 1, 1)
	input_table['language'] = dlg:add_dropdown(2, 1, 2, 1)
	dlg:add_button(lang["int_search_hash"], searchHash, 4, 1, 1, 1)

	dlg:add_label(lang["int_title"] .. ':', 1, 2, 1, 1)
	input_table['title'] = dlg:add_text_input(cruise.movie.title or "", 2, 2, 2, 1)
	dlg:add_button(lang["int_search_name"], searchIMBD, 4, 2, 1, 1)
	dlg:add_label(lang["int_season"] .. ':', 1, 3, 1, 1)
	input_table['seasonNumber'] = dlg:add_text_input(cruise.movie.seasonNumber or "", 2, 3, 2, 1)
	dlg:add_label(lang["int_episode"] .. ':', 1, 4, 1, 1)
	input_table['episodeNumber'] = dlg:add_text_input(cruise.movie.episodeNumber or "", 2, 4, 2, 1)
	input_table['mainlist'] = dlg:add_list(1, 5, 4, 1)
	input_table['message'] = nil
	input_table['message'] = dlg:add_label(' ', 1, 6, 4, 1)
	dlg:add_button(lang["int_show_help"], show_help, 1, 7, 1, 1)
	dlg:add_button('   ' .. lang["int_show_conf"] .. '   ', show_conf, 2, 7, 1, 1)
	dlg:add_button(lang["int_dowload_sel"], download_subtitles, 3, 7, 1, 1)
	dlg:add_button(lang["int_close"], deactivate, 4, 7, 1, 1)

	assoc_select_conf('language', 'language', cruise.conf.languages, 2, lang["int_all"])

	display_subtitles()
end

function set_interface_main()
	-- Update movie title and co. if video input change
	if not type(input_table['title']) == 'userdata' then return false end

	cruise.getFileInfo()
	cruise.getMovieInfo()

	input_table['title']:set_text(
	cruise.movie.title or "")
	input_table['episodeNumber']:set_text(
	cruise.movie.episodeNumber or "")
	input_table['seasonNumber']:set_text(
	cruise.movie.seasonNumber or "")
end

function interface_config()
	input_table['intLangLab'] = dlg:add_label(
	lang["int_int_lang"] .. ':', 1, 1, 1, 1)
	input_table['intLangBut'] = dlg:add_button(
	lang["int_search_transl"],
	get_available_translations, 2, 1, 1, 1)
	input_table['intLang'] = dlg:add_dropdown(3, 1, 1, 1)
	dlg:add_label(
	lang["int_default_lang"] .. ':', 1, 2, 2, 1)
	input_table['default_language'] = dlg:add_dropdown(3, 2, 1, 1)
	dlg:add_label(
	lang["int_dowload_behav"] .. ':', 1, 3, 2, 1)
	input_table['downloadBehaviour'] = dlg:add_dropdown(3, 3, 1, 1)
	dlg:add_label(
	lang["int_display_code"] .. ':', 1, 4, 0, 1)
	input_table['langExt'] = dlg:add_dropdown(3, 4, 1, 1)
	dlg:add_label(
	lang["int_remove_tag"] .. ':', 1, 5, 0, 1)
	input_table['removeTag'] = dlg:add_dropdown(3, 5, 1, 1)

	if cruise.conf.dirPath then
		if cruise.conf.os == "win" then
			dlg:add_label(
			"<a href='file:///" .. cruise.conf.dirPath .. "'>" ..
			lang["int_vlsub_work_dir"] .. "</a>", 1, 6, 2, 1)
		else
			dlg:add_label(
			"<a href='" .. cruise.conf.dirPath .. "'>" ..
			lang["int_vlsub_work_dir"] .. "</a>", 1, 6, 2, 1)
		end
	else
		dlg:add_label(
		lang["int_vlsub_work_dir"], 1, 6, 2, 1)
	end

	input_table['dir_path'] = dlg:add_text_input(
	cruise.conf.dirPath, 2, 6, 2, 1)

	dlg:add_label(
	lang["int_os_username"] .. ':', 1, 7, 0, 1)
	input_table['os_username'] = dlg:add_text_input(
	type(cruise.option.os_username) == "string"
	and cruise.option.os_username or "", 2, 7, 2, 1)
	dlg:add_label(
	lang["int_os_password"] .. ':', 1, 8, 0, 1)
	input_table['os_password'] = dlg:add_text_input(
	type(cruise.option.os_password) == "string"
	and cruise.option.os_password or "", 2, 8, 2, 1)

	input_table['message'] = nil
	input_table['message'] = dlg:add_label(' ', 1, 9, 3, 1)

	dlg:add_button(
	lang["int_cancel"],
	show_main, 2, 10, 1, 1)
	dlg:add_button(
	lang["int_save"],
	apply_config, 3, 10, 1, 1)

	input_table['langExt']:add_value(
	lang["int_bool_" .. tostring(cruise.option.langExt)], 1)
	input_table['langExt']:add_value(
	lang["int_bool_" .. tostring(not cruise.option.langExt)], 2)
	input_table['removeTag']:add_value(
	lang["int_bool_" .. tostring(cruise.option.removeTag)], 1)
	input_table['removeTag']:add_value(
	lang["int_bool_" .. tostring(not cruise.option.removeTag)], 2)

	assoc_select_conf(
	'intLang',
	'intLang',
	cruise.conf.translations_avail,
	2)
	assoc_select_conf(
	'default_language',
	'language',
	cruise.conf.languages,
	2,
	lang["int_all"])
	assoc_select_conf(
	'downloadBehaviour',
	'downloadBehaviour',
	cruise.conf.downloadBehaviours,
	1)
end

function interface_help()
	local help_html = lang["int_help_mess"]
	input_table['help'] = dlg:add_html(help_html, 1, 1, 4, 1)
	dlg:add_label(string.rep("&nbsp;", 100), 1, 2, 3, 1)
	dlg:add_button(lang["int_ok"], show_main, 4, 2, 1, 1)
end

function interface_no_support()
	local no_support_html = lang["int_no_support_mess"]
	input_table['no_support'] = dlg:add_html(no_support_html, 1, 1, 4, 1)
	dlg:add_label(string.rep("&nbsp;", 100), 1, 2, 3, 1)
end

function trigger_menu(dlg_id)
	if dlg_id == 1 then
		close_dlg()
		dlg = vlc.dialog(
		cruise.conf.useragent)
		interface_main()
	elseif dlg_id == 2 then
		close_dlg()
		dlg = vlc.dialog(
		cruise.conf.useragent .. ': ' .. lang["int_configuration"])
		interface_config()
	elseif dlg_id == 3 then
		close_dlg()
		dlg = vlc.dialog(
		cruise.conf.useragent .. ': ' .. lang["int_help"])
		interface_help()
	end
	collectgarbage()
	-- ~ !important	
end 

function show_main()
	trigger_menu(1)
end

function show_conf()
	trigger_menu(2)
end

function show_help()
	trigger_menu(3)
end

function close_dlg()
	vlc.msg.dbg("[cruise] Closing dialog")
	if dlg ~= nil then
		-- ~ dlg:delete() -- Throw an error
		dlg:hide()
	end

	dlg = nil
	input_table = nil
	input_table = { }
	collectgarbage()
	-- ~ !important	
end

--[[ Drop down / config association ]]--
function assoc_select_conf(select_id, option, conf, ind, default)
	-- Helper for i/o interaction between drop down and option list
	select_conf[select_id] = {
		cf = conf,
		opt = option,
		dflt = default,
		ind = ind
	}
	set_default_option(select_id)
	display_select(select_id)
end

function set_default_option(select_id)
	-- Put the selected option of a list in first place of the associated table
	local opt = select_conf[select_id].opt
	local cfg = select_conf[select_id].cf
	local ind = select_conf[select_id].ind
	if cruise.option[opt] then
		table.sort(cfg, function(a, b)
			if a[1] == cruise.option[opt] then
				return true
			elseif b[1] == cruise.option[opt] then
				return false
			else
				return a[ind] < b[ind]
			end
		end )
	end
end

function display_select(select_id)
	-- Display the drop down values with an optional default value at the top
	local conf = select_conf[select_id].cf
	local opt = select_conf[select_id].opt
	local option = cruise.option[opt]
	local default = select_conf[select_id].dflt
	local default_isset = false

	if not default then
		default_isset = true
	end

	for k, l in ipairs(conf) do
		if default_isset then
			input_table[select_id]:add_value(l[2], k)
		else
			if option then
				input_table[select_id]:add_value(l[2], k)
				input_table[select_id]:add_value(default, 0)
			else
				input_table[select_id]:add_value(default, 0)
				input_table[select_id]:add_value(l[2], k)
			end
			default_isset = true
		end
	end
end

--[[ Config & interface localization ]]--
function check_config()
	-- Make a copy of english translation to use it as default
	-- in case some element aren't translated in other translations
	eng_translation = { }
	for k, v in pairs(cruise.option.translation) do
		eng_translation[k] = v
	end

	-- Get available translation full name from code
	trsl_names = { }
	for i, lg in ipairs(languages) do
		trsl_names[lg[1]] = lg[2]
	end

	if is_window_path(vlc.config.datadir()) then
		cruise.conf.os = "win"
		slash = "\\"
	else
		cruise.conf.os = "lin"
		slash = "/"
	end

	local path_generic = { "lua", "extensions", "userdata", "vlsub" }
	local dirPath = slash .. table.concat(path_generic, slash)
	local filePath = slash .. "vlsub_conf.xml"
	local config_saved = false
	sub_dir = slash .. "vlsub_subtitles"

	-- Check if config file path is stored in vlc config
	local other_dirs = { }

	for
		path in
		vlc.config.get("sub-autodetect-path"):gmatch("[^,]+")
	do
		if path:match(".*" .. sub_dir .. "$") then
			cruise.conf.dirPath = path:gsub(
			"%s*(.*)" .. sub_dir .. "%s*$", "%1")
			config_saved = true
		end
		table.insert(other_dirs, path)
	end

	-- if not stored in vlc config
	-- try to find a suitable config file path

	if cruise.conf.dirPath then
		if not is_dir(cruise.conf.dirPath) and
			(cruise.conf.os == "lin" or
			is_win_safe(cruise.conf.dirPath)) then
			mkdir_p(cruise.conf.dirPath)
		end
	else
		local userdatadir = vlc.config.userdatadir()
		local datadir = vlc.config.datadir()

		-- check if the config already exist
		if file_exist(userdatadir .. dirPath .. filePath) then
			-- in vlc.config.userdatadir()
			cruise.conf.dirPath = userdatadir .. dirPath
			config_saved = true
		elseif file_exist(datadir .. dirPath .. filePath) then
			-- in vlc.config.datadir()
			cruise.conf.dirPath = datadir .. dirPath
			config_saved = true
		else
			-- if not found determine an accessible path
			local extension_path = slash .. path_generic[1]
			.. slash .. path_generic[2]

			-- use the same folder as the extension if accessible
			if is_dir(userdatadir .. extension_path)
				and file_touch(userdatadir .. dirPath .. filePath) then
				cruise.conf.dirPath = userdatadir .. dirPath
			elseif file_touch(datadir .. dirPath .. filePath) then
				cruise.conf.dirPath = datadir .. dirPath
			end

			-- try to create working dir in user folder
			if not cruise.conf.dirPath
				and is_dir(userdatadir) then
				if not is_dir(userdatadir .. dirPath) then
					mkdir_p(userdatadir .. dirPath)
				end
				if is_dir(userdatadir .. dirPath) and
					file_touch(userdatadir .. dirPath .. filePath) then
					cruise.conf.dirPath = userdatadir .. dirPath
				end
			end

			-- try to create working dir in vlc folder	
			if not cruise.conf.dirPath and
				is_dir(datadir) then
				if not is_dir(datadir .. dirPath) then
					mkdir_p(datadir .. dirPath)
				end
				if file_touch(datadir .. dirPath .. filePath) then
					cruise.conf.dirPath = datadir .. dirPath
				end
			end
		end
	end

	if cruise.conf.dirPath then
		vlc.msg.dbg("[cruise] Working directory: " ..
		(cruise.conf.dirPath or "not found"))

		cruise.conf.filePath = cruise.conf.dirPath .. filePath
		cruise.conf.localePath = cruise.conf.dirPath .. slash .. "locale"

		if config_saved
			and file_exist(cruise.conf.filePath) then
			vlc.msg.dbg(
			"[cruise] Loading config file: " .. cruise.conf.filePath)
			load_config()
		else
			vlc.msg.dbg("[cruise] No config file")
			getenv_lang()
			config_saved = save_config()
			if not config_saved then
				vlc.msg.dbg("[cruise] Unable to save config")
			end
		end

		-- Check presence of a translation file
		-- in "%vlsub_directory%/locale"
		-- Add translation files to available translation list
		local file_list = list_dir(cruise.conf.localePath)
		local translations_avail = cruise.conf.translations_avail

		if file_list then
			for i, file_name in ipairs(file_list) do
				local lg = string.gsub(
				file_name,
				"^(%w%w%w).xml$",
				"%1")
				if lg
					and not cruise.option.translations_avail[lg] then
					table.insert(translations_avail, {
						lg,
						trsl_names[lg]
					} )
				end
			end
		end

		-- Load selected translation from file
		if cruise.option.intLang ~= "eng"
			and not cruise.conf.translated
		then
			local transl_file_path = cruise.conf.localePath ..
			slash .. cruise.option.intLang .. ".xml"
			if file_exist(transl_file_path) then
				vlc.msg.dbg(
				"[cruise] Loading translation from file: " ..
				transl_file_path)
				load_transl(transl_file_path)
			end
		end
	else
		vlc.msg.dbg("[cruise] Unable to find a suitable path" ..
		"to save config, please set it manually")
	end

	lang = nil
	lang = options.translation
	-- just a short cut

	if not vlc.net or not vlc.net.poll then
		dlg = vlc.dialog(
		cruise.conf.useragent .. ': ' .. lang["mess_error"])
		interface_no_support()
		dlg:show()
		return false
	end

	SetDownloadBehaviours()
	if not cruise.conf.dirPath then
		setError(lang["mess_err_conf_access"])
	end

	-- Set table list of available translations from assoc. array
	-- so it is sortable

	for k, l in pairs(cruise.option.translations_avail) do
		if k == cruise.option.int_research then
			table.insert(cruise.conf.translations_avail, 1, { k, l })
		else
			table.insert(cruise.conf.translations_avail, { k, l })
		end
	end
	collectgarbage()
	return true
end

function load_config()
	-- Overwrite default conf with loaded conf
	local tmpFile = io.open(cruise.conf.filePath, "rb")
	if not tmpFile then return false end
	local resp = tmpFile:read("*all")
	tmpFile:flush()
	tmpFile:close()
	local option = parse_xml(resp)

	for key, value in pairs(option) do
		if type(value) == "table" then
			if key == "translation" then
				cruise.conf.translated = true
				for k, v in pairs(value) do
					cruise.option.translation[k] = v
				end
			else
				cruise.option[key] = value
			end
		else
			if value == "true" then
				cruise.option[key] = true
			elseif value == "false" then
				cruise.option[key] = false
			else
				cruise.option[key] = value
			end
		end
	end
	collectgarbage()
end

function load_transl(path)
	-- Overwrite default conf with loaded conf
	local tmpFile = assert(io.open(path, "rb"))
	local resp = tmpFile:read("*all")
	tmpFile:flush()
	tmpFile:close()
	cruise.option.translation = nil

	cruise.option.translation = parse_xml(resp)
	collectgarbage()
end

function apply_translation()
	-- Overwrite default conf with loaded conf
	for k, v in pairs(eng_translation) do
		if not cruise.option.translation[k] then
			cruise.option.translation[k] = eng_translation[k]
		end
	end
end

function getenv_lang()
	-- Retrieve the user OS language
	local os_lang = os.getenv("LANG")
	if os_lang then
		-- unix, mac
		os_lang = string.sub(os_lang, 0, 2)
		if type(lang_os_to_iso[os_lang]) then
			cruise.option.language = lang_os_to_iso[os_lang]
		end
	else
		-- Windows
		local lang_w = string.match(
		os.setlocale("", "collate"), "^[^_]+")
		for i, v in ipairs(cruise.conf.languages) do
			if v[2] == lang_w then
				cruise.option.language = v[1]
			end
		end
	end
end

function apply_config()
	-- Apply user config selection to local config
	local lg_sel = input_table['intLang']:get_value()
	local sel_val
	local opt
	local sel_cf

	if lg_sel and lg_sel ~= 1
		and cruise.conf.translations_avail[lg_sel] then
		local lg = cruise.conf.translations_avail[lg_sel][1]
		set_translation(lg)
		SetDownloadBehaviours()
	end

	for select_id, v in pairs(select_conf) do
		if input_table[select_id]
			and select_conf[select_id] then
			sel_val = input_table[select_id]:get_value()
			sel_cf = select_conf[select_id]
			opt = sel_cf.opt

			if sel_val == 0 then
				cruise.option[opt] = nil
			else
				cruise.option[opt] = sel_cf.cf[sel_val][1]
			end

			set_default_option(select_id)
		end
	end


	cruise.option.os_username = input_table['os_username']:get_text()
	cruise.option.os_password = input_table['os_password']:get_text()

	if input_table["langExt"]:get_value() == 2 then
		cruise.option.langExt = not cruise.option.langExt
	end

	if input_table["removeTag"]:get_value() == 2 then
		cruise.option.removeTag = not cruise.option.removeTag
	end

	-- Set a custom working directory
	local dir_path = input_table['dir_path']:get_text()
	local dir_path_err = false
	if trim(dir_path) == "" then dir_path = nil end

	if dir_path ~= cruise.conf.dirPath then
		if cruise.conf.os == "lin"
			or is_win_safe(dir_path)
			or not dir_path then
			local other_dirs = { }

			for
				path in
				vlc.config.get(
				"sub-autodetect-path"):gmatch("[^,]+"
				)
			do
				path = trim(path)
				if path ~=(cruise.conf.dirPath or "") .. sub_dir then
					table.insert(other_dirs, path)
				end
			end
			cruise.conf.dirPath = dir_path
			if dir_path then
				table.insert(other_dirs,
				string.gsub(dir_path, "^(.-)[\\/]?$", "%1") .. sub_dir)

				if not is_dir(dir_path) then
					mkdir_p(dir_path)
				end

				cruise.conf.filePath = cruise.conf.dirPath ..
				slash .. "vlsub_conf.xml"
				cruise.conf.localePath = cruise.conf.dirPath ..
				slash .. "locale"
			else
				cruise.conf.filePath = nil
				cruise.conf.localePath = nil
			end
			vlc.config.set(
			"sub-autodetect-path",
			table.concat(other_dirs, ", "))
		else
			dir_path_err = true
			setError(lang["mess_err_wrong_path"] ..
			"<br><b>" ..
			string.gsub(
			dir_path,
			"[^%:%w%p%s§¤]+",
			"<span style='color:#B23'>%1</span>"
			) ..
			"</b>")
		end
	end

	if cruise.conf.dirPath and
		not dir_path_err then
		local config_saved = save_config()
		trigger_menu(1)
		if not config_saved then
			setError(lang["mess_err_conf_access"])
		end
	else
		setError(lang["mess_err_conf_access"])
	end
end

function save_config()
	-- Dump local config into config file
	if cruise.conf.dirPath
		and cruise.conf.filePath then
		vlc.msg.dbg(
		"[cruise] Saving config file:  " ..
		cruise.conf.filePath)

		if file_touch(cruise.conf.filePath) then
			local tmpFile = assert(
			io.open(cruise.conf.filePath, "wb"))
			local resp = dump_xml(cruise.option)
			tmpFile:write(resp)
			tmpFile:flush()
			tmpFile:close()
			tmpFile = nil
		else
			return false
		end
		collectgarbage()
		return true
	else
		vlc.msg.dbg("[cruise] Unable fount a suitable path " ..
		"to save config, please set it manually")
		setError(lang["mess_err_conf_access"])
		return false
	end
end

function SetDownloadBehaviours()
	cruise.conf.downloadBehaviours = nil
	cruise.conf.downloadBehaviours = {
		{ 'save', lang["int_dowload_save"] },
		{ 'manual', lang["int_dowload_manual"] }
	}
end

function get_available_translations()
	-- Get all available translation files from the internet
	-- (drop previous direct download from github repo
	-- causing error  with github https CA certficate on OS X an XP)
	-- https://github.com/exebetche/vlsub/tree/master/locale

	local translations_url = "http://addons.videolan.org/CONTENT/" ..
	"content-files/148752-vlsub_translations.xml"

	if input_table['intLangBut']:get_text() == lang["int_search_transl"]
	then
		cruise.actionLabel = lang["int_searching_transl"]

		local translations_content, lol = get(translations_url)
		local translations_avail = cruise.option.translations_avail
		all_trsl = parse_xml(translations_content)
		local lg, trsl

		for lg, trsl in pairs(all_trsl) do
			if lg ~= options.intLang[1]
				and not translations_avail[lg] then
				translations_avail[lg] = trsl_names[lg] or ""
				table.insert(cruise.conf.translations_avail, {
					lg,
					trsl_names[lg]
				} )
				input_table['intLang']:add_value(
				trsl_names[lg],
				#cruise.conf.translations_avail)
			end
		end

		setMessage(success_tag(lang["mess_complete"]))
		collectgarbage()
	end
end

function set_translation(lg)
	cruise.option.translation = nil
	cruise.option.translation = { }

	if lg == 'eng' then
		for k, v in pairs(eng_translation) do
			cruise.option.translation[k] = v
		end
	else
		-- If translation file exists in /locale directory load it
		if cruise.conf.localePath
			and file_exist(cruise.conf.localePath ..
			slash .. lg .. ".xml") then
			local transl_file_path = cruise.conf.localePath ..
			slash .. lg .. ".xml"
			vlc.msg.dbg("[cruise] Loading translation from file: " ..
			transl_file_path)
			load_transl(transl_file_path)
			apply_translation()
		else
			-- Load translation file from internet
			if not all_trsl then
				get_available_translations()
			end

			if not all_trsl or not all_trsl[lg] then
				vlc.msg.dbg("[cruise] Error, translation not found")
				return false
			end
			cruise.option.translation = all_trsl[lg]
			apply_translation()
			all_trsl = nil
		end
	end

	lang = nil
	lang = cruise.option.translation
	collectgarbage()
end 

--[[ Core ]]--

cruise = {
	itemStore = nil,
	actionLabel = "",
	conf =
	{
		url = "http://api.opensubtitles.org/xml-rpc",
		path = nil,
		userAgentHTTP = "cruise",
		useragent = "cruise 0.9",
		translations_avail = { },
		downloadBehaviours = nil,
		languages = languages
	},
	option = options,
	session =
	{
		loginTime = 0,
		token = ""
	},
	file =
	{
		hasInput = false,
		uri = nil,
		ext = nil,
		name = nil,
		path = nil,
		protocol = nil,
		cleanName = nil,
		dir = nil,
		hash = nil,
		bytesize = nil,
		fps = nil,
		timems = nil,
		frames = nil
	},
	movie =
	{
		title = "",
		seasonNumber = "",
		episodeNumber = "",
		sublanguageid = ""
	},
	request = function(methodName)
		local params = cruise.methods[methodName].params()
		local reqTable = cruise.getMethodBase(methodName, params)
		local request = "<?xml version='1.0'?>" .. dump_xml(reqTable)
		local host, path = parse_url(cruise.conf.url)
		local header = {
			"POST " .. path .. " HTTP/1.1",
			"Host: " .. host,
			"User-Agent: " .. cruise.conf.userAgentHTTP,
			"Content-Type: text/xml",
			"Content-Length: " .. string.len(request),
			"",
			""
		}
		request = table.concat(header, "\r\n") .. request

		local response
		local status, responseStr = http_req(host, 80, request)

		if status == 200 then
			response = parse_xmlrpc(responseStr)
			if response then
				if response.status == "200 OK" then
					return cruise.methods[methodName]
					.callback(response)
				elseif response.status == "406 No session" then
					cruise.request("LogIn")
				elseif response then
					setError("code '" ..
					response.status ..
					"' (" .. status .. ")")
					return false
				end
			else
				setError("Server not responding")
				return false
			end
		elseif status == 401 then
			setError("Request unauthorized")

			response = parse_xmlrpc(responseStr)
			if cruise.session.token ~= response.token then
				setMessage("Session expired, retrying")
				cruise.session.token = response.token
				cruise.request(methodName)
			end
			return false
		elseif status == 503 then
			setError("Server overloaded, please retry later")
			return false
		end

	end,
	getMethodBase = function(methodName, param)
		if cruise.methods[methodName].methodName then
			methodName = cruise.methods[methodName].methodName
		end

		local request = {
			methodCall =
			{
				methodName = methodName,
				params = { param = param }
			}
		}

		return request
	end,
	methods =
	{
		LogIn =
		{
			params = function()
				cruise.actionLabel = lang["action_login"]
				return {
					{ value = { string = cruise.option.os_username } },
					{ value = { string = cruise.option.os_password } },
					{ value = { string = cruise.movie.sublanguageid } },
					{ value = { string = cruise.conf.useragent } }
				}
			end,
			callback = function(resp)
				cruise.session.token = resp.token
				cruise.session.loginTime = os.time()
				return true
			end
		},
		LogOut =
		{
			params = function()
				cruise.actionLabel = lang["action_logout"]
				return {
					{ value = { string = cruise.session.token } }
				}
			end,
			callback = function()
				return true
			end
		},
		NoOperation =
		{
			params = function()
				cruise.actionLabel = lang["action_noop"]
				return {
					{ value = { string = cruise.session.token } }
				}
			end,
			callback = function(resp)
				return true
			end
		},
		SearchSubtitlesByHash =
		{
			methodName = "SearchSubtitles",
			params = function()
				cruise.actionLabel = lang["action_search"]
				setMessage(cruise.actionLabel .. ": " ..
				progressBarContent(0))

				return {
					{ value = { string = cruise.session.token } },
					{
						value =
						{
							array =
							{
								data =
								{
									value =
									{
										struct =
										{
											member =
											{
												{
													name = "sublanguageid",
													value =
													{
														string = cruise.movie.sublanguageid
													}
												},
												{
													name = "moviehash",
													value =
													{
														string = cruise.file.hash
													}
												},
												{
													name = "moviebytesize",
													value =
													{
														double = cruise.file.bytesize
													}
												}
											}
										}
									}
								}
							}
						}
					}
				}
			end,
			callback = function(resp)
				cruise.itemStore = resp.data
			end
		},
		SearchSubtitles =
		{
			methodName = "SearchSubtitles",
			params = function()
				cruise.actionLabel = lang["action_search"]
				setMessage(cruise.actionLabel .. ": " ..
				progressBarContent(0))

				local member = {
					{
						name = "sublanguageid",
						value =
						{
							string = cruise.movie.sublanguageid
						}
					},
					{
						name = "query",
						value =
						{
							string = cruise.movie.title
						}
					}
				}


				if cruise.movie.seasonNumber ~= nil then
					table.insert(member, {
						name = "season",
						value =
						{
							string = cruise.movie.seasonNumber
						}
					} )
				end

				if cruise.movie.episodeNumber ~= nil then
					table.insert(member, {
						name = "episode",
						value =
						{
							string = cruise.movie.episodeNumber
						}
					} )
				end

				return {
					{ value = { string = cruise.session.token } },
					{
						value =
						{
							array =
							{
								data =
								{
									value =
									{
										struct =
										{
											member = member
										}
									}
								}
							}
						}
					}
				}
			end,
			callback = function(resp)
				cruise.itemStore = resp.data
			end
		}
	},
	getInputItem = function()
		return vlc.item or vlc.input.item()
	end,
	getFileInfo = function()
		-- Get video file path, name, extension from input uri
		local item = cruise.getInputItem()
		local file = cruise.file
		if not item then
			file.hasInput = false;
			file.cleanName = nil;
			file.protocol = nil;
			file.path = nil;
			file.ext = nil;
			file.uri = nil;
		else
			vlc.msg.dbg("[cruise] Video URI: " .. item:uri())
			local parsed_uri = vlc.net.url_parse(item:uri())
			file.uri = item:uri()
			file.protocol = parsed_uri["protocol"]
			file.path = parsed_uri["path"]

			-- Corrections

			-- For windows
			file.path = string.match(file.path, "^/(%a:/.+)$") or file.path

			-- For file in archive
			local archive_path, name_in_archive = string.match(
			file.path, '^([^!]+)!/([^!/]*)$')
			if archive_path and archive_path ~= "" then
				file.path = string.gsub(
				archive_path,
				'\063',
				'%%')
				file.path = vlc.strings.decode_uri(file.path)
				file.completeName = string.gsub(
				name_in_archive,
				'\063',
				'%%')
				file.completeName = vlc.strings.decode_uri(
				file.completeName)
				file.is_archive = true
			else
				-- "classic" input
				file.path = vlc.strings.decode_uri(file.path)
				file.dir, file.completeName = string.match(
				file.path,
				'^(.+/)([^/]*)$')

				local file_stat = vlc.net.stat(file.path)
				if file_stat
				then
					file.stat = file_stat
				end

				file.is_archive = false
			end

			file.name, file.ext = string.match(
			file.completeName,
			'^([^/]-)%.?([^%.]*)$')

			if file.ext == "part" then
				file.name, file.ext = string.match(
				file.name,
				'^([^/]+)%.([^%.]+)$')
			end

			file.hasInput = true;
			file.cleanName = string.gsub(
			file.name,
			"[%._]", " ")
			vlc.msg.dbg("[cruise] file info " ..(dump_xml(file)))
		end
		collectgarbage()
	end,
	getMovieInfo = function()
		-- Clean video file name and check for season/episode pattern in title
		if not cruise.file.name then
			cruise.movie.title = ""
			cruise.movie.seasonNumber = ""
			cruise.movie.episodeNumber = ""
			return false
		end

		local showName, seasonNumber, episodeNumber = string.match(
		cruise.file.cleanName,
		"(.+)[sS](%d%d)[eE](%d%d).*")

		if not showName then
			showName, seasonNumber, episodeNumber = string.match(
			cruise.file.cleanName,
			"(.+)(%d)[xX](%d%d).*")
		end

		if showName then
			cruise.movie.title = showName
			cruise.movie.seasonNumber = seasonNumber
			cruise.movie.episodeNumber = episodeNumber
		else
			cruise.movie.title = cruise.file.cleanName
			cruise.movie.seasonNumber = ""
			cruise.movie.episodeNumber = ""
		end
		collectgarbage()
	end,
	getMovieHash = function()
		-- Calculate movie hash
		cruise.actionLabel = lang["action_hash"]
		setMessage(cruise.actionLabel .. ": " ..
		progressBarContent(0))

		local item = cruise.getInputItem()

		if not item then
			setError(lang["mess_no_input"])
			return false
		end

		cruise.getFileInfo()

		if not cruise.file.path then
			setError(lang["mess_not_found"])
			return false
		end

		local data_start = ""
		local data_end = ""
		local size
		local chunk_size = 65536

		-- Get data for hash calculation
		if cruise.file.is_archive then
			vlc.msg.dbg("[cruise] Read hash data from stream")

			local file = vlc.stream(cruise.file.uri)
			local dataTmp1 = ""
			local dataTmp2 = ""
			size = chunk_size

			data_start = file:read(chunk_size)

			while data_end do
				size = size + string.len(data_end)
				dataTmp1 = dataTmp2
				dataTmp2 = data_end
				data_end = file:read(chunk_size)
				collectgarbage()
			end
			data_end = string.sub((dataTmp1 .. dataTmp2), - chunk_size)
		elseif not file_exist(cruise.file.path)
			and cruise.file.stat then
			vlc.msg.dbg("[cruise] Read hash data from stream")

			local file = vlc.stream(cruise.file.uri)

			if not file then
				vlc.msg.dbg("[cruise] No stream")
				return false
			end

			size = cruise.file.stat.size
			local decal = size % chunk_size

			data_start = file:read(chunk_size)

			-- "Seek" to the end
			file:read(decal)

			for i = 1, math.floor(((size - decal) / chunk_size)) -2 do
				file:read(chunk_size)
			end

			data_end = file:read(chunk_size)

			file = nil
		else
			vlc.msg.dbg("[cruise] Read hash data from file")
			local file = io.open(cruise.file.path, "rb")
			if not file then
				vlc.msg.dbg("[cruise] No stream")
				return false
			end

			data_start = file:read(chunk_size)
			size = file:seek("end", - chunk_size) + chunk_size
			data_end = file:read(chunk_size)
			file = nil
		end

		-- Hash calculation
		local lo = size
		local hi = 0
		local o, a, b, c, d, e, f, g, h
		local hash_data = data_start .. data_end
		local max_size = 4294967296
		local overflow

		for i = 1, #hash_data, 8 do
			a, b, c, d, e, f, g, h = hash_data:byte(i, i + 7)
			lo = lo + a + b * 256 + c * 65536 + d * 16777216
			hi = hi + e + f * 256 + g * 65536 + h * 16777216

			if lo > max_size then
				overflow = math.floor(lo / max_size)
				lo = lo -(overflow * max_size)
				hi = hi + overflow
			end

			if hi > max_size then
				overflow = math.floor(hi / max_size)
				hi = hi -(overflow * max_size)
			end
		end

		cruise.file.bytesize = size
		cruise.file.hash = string.format("%08x%08x", hi, lo)
		vlc.msg.dbg("[cruise] Video hash: " .. cruise.file.hash)
		vlc.msg.dbg("[cruise] Video bytesize: " .. size)
		collectgarbage()
		return true
	end,
	checkSession = function()

		if cruise.session.token == "" then
			cruise.request("LogIn")
		else
			cruise.request("NoOperation")
		end
	end
}

function searchHash()
	local sel = input_table["language"]:get_value()
	if sel == 0 then
		cruise.movie.sublanguageid = 'all'
	else
		cruise.movie.sublanguageid = cruise.conf.languages[sel][1]
	end

	cruise.getMovieHash()

	if cruise.file.hash then
		cruise.checkSession()
		cruise.request("SearchSubtitlesByHash")
		display_subtitles()
	end
end

function searchIMBD()
	cruise.movie.title = trim(input_table["title"]:get_text())
	cruise.movie.seasonNumber = tonumber(
	input_table["seasonNumber"]:get_text())
	cruise.movie.episodeNumber = tonumber(
	input_table["episodeNumber"]:get_text())

	local sel = input_table["language"]:get_value()
	if sel == 0 then
		cruise.movie.sublanguageid = 'all'
	else
		cruise.movie.sublanguageid = cruise.conf.languages[sel][1]
	end

	if cruise.movie.title ~= "" then
		cruise.checkSession()
		cruise.request("SearchSubtitles")
		display_subtitles()
	end
end

function display_subtitles()
	local mainlist = input_table["mainlist"]
	mainlist:clear()

	if cruise.itemStore == "0" then
		mainlist:add_value(lang["mess_no_res"], 1)
		setMessage("<b>" .. lang["mess_complete"] .. ":</b> " ..
		lang["mess_no_res"])
	elseif cruise.itemStore then
		for i, item in ipairs(cruise.itemStore) do
			mainlist:add_value(
			item.SubFileName ..
			" [" .. item.SubLanguageID .. "]" ..
			" (" .. item.SubSumCD .. " CD)", i)
		end
		setMessage("<b>" .. lang["mess_complete"] .. ":</b> " ..
		#(cruise.itemStore) .. "  " .. lang["mess_res"])
	end
end

function get_first_sel(list)
	local selection = list:get_selection()
	for index, name in pairs(selection) do
		return index
	end
	return 0
end

function download_subtitles()
	local index = get_first_sel(input_table["mainlist"])

	if index == 0 then
		setMessage(lang["mess_no_selection"])
		return false
	end

	cruise.actionLabel = lang["mess_downloading"]

	local item = cruise.itemStore[index]

	if cruise.option.downloadBehaviour == 'manual'
		or not cruise.file.hasInput then
		local link = "<span style='color:#181'>"
		link = link .. "<b>" .. lang["mess_dowload_link"] .. ":</b>"
		link = link .. "</span> &nbsp;"
		link = link .. "</span> &nbsp;<a href='" ..
		item.ZipDownloadLink .. "'>"
		link = link .. item.MovieReleaseName .. "</a>"

		setMessage(link)
		return false
	end

	local message = ""
	local subfileName = cruise.file.name or ""

	if cruise.option.langExt then
		subfileName = subfileName .. "." .. item.SubLanguageID
	end

	subfileName = subfileName .. "." .. item.SubFormat
	local tmp_dir
	local file_target_access = true

	if is_dir(cruise.file.dir) then
		tmp_dir = cruise.file.dir
	elseif cruise.conf.dirPath then
		tmp_dir = cruise.conf.dirPath

		message = "<br>" .. error_tag(lang["mess_save_fail"] .. " &nbsp;" ..
		"<a href='" .. vlc.strings.make_uri(cruise.conf.dirPath) .. "'>" ..
		lang["mess_click_link"] .. "</a>")
	else
		setError(lang["mess_save_fail"] .. " &nbsp;" ..
		"<a href='" .. item.ZipDownloadLink .. "'>" ..
		lang["mess_click_link"] .. "</a>")
		return false
	end

	local tmpFileURI, tmpFileName = dump_zip(
	item.ZipDownloadLink,
	tmp_dir,
	item.SubFileName)

	vlc.msg.dbg("[cruise] tmpFileName: " .. tmpFileName)

	-- Determine if the path to the video file is accessible for writing

	local target = cruise.file.dir .. subfileName

	if not file_touch(target) then
		if cruise.conf.dirPath then
			target = cruise.conf.dirPath .. slash .. subfileName
			message = "<br>" ..
			error_tag(lang["mess_save_fail"] .. " &nbsp;" ..
			"<a href='" .. vlc.strings.make_uri(
			cruise.conf.dirPath) .. "'>" ..
			lang["mess_click_link"] .. "</a>")
		else
			setError(lang["mess_save_fail"] .. " &nbsp;" ..
			"<a href='" .. item.ZipDownloadLink .. "'>" ..
			lang["mess_click_link"] .. "</a>")
			return false
		end
	end

	vlc.msg.dbg("[cruise] Subtitles files: " .. target)

	-- Unzipped data into file target

	local stream = vlc.stream(tmpFileURI)
	local data = ""
	local subfile = io.open(target, "wb")

	while data do
		subfile:write(data)
		data = stream:read(65536)
	end

	subfile:flush()
	subfile:close()

	stream = nil
	collectgarbage()

	if not os.remove(tmpFileName) then
		vlc.msg.err("[cruise] Unable to remove temp: " .. tmpFileName)
	end

	-- load subtitles
	if add_sub(target) then
		message = success_tag(lang["mess_loaded"]) .. message
	else
		message = error_tag(lang["mess_not_load"]) .. message
	end

	setMessage(message)
end

function dump_zip(url, dir, subfileName)
	-- Dump zipped data in a temporary file
	setMessage(cruise.actionLabel .. ": " .. progressBarContent(0))
	local resp = get(url)

	if not resp then
		setError(lang["mess_no_response"])
		return false
	end

	local tmpFileName = dir .. subfileName .. ".gz"
	if not file_touch(tmpFileName) then
		return false
	end
	local tmpFile = assert(io.open(tmpFileName, "wb"))

	tmpFile:write(resp)
	tmpFile:flush()
	tmpFile:close()
	tmpFile = nil
	collectgarbage()
	return "zip://" .. make_uri(tmpFileName) .. "!/" .. subfileName, tmpFileName
end

function add_sub(subPath)
	if vlc.item or vlc.input.item() then
		subPath = decode_uri(subPath)
		vlc.msg.dbg("[cruise] Adding subtitle :" .. subPath)
		return vlc.input.add_subtitle(subPath)
	end
	return false
end

--[[ Interface helpers ]]--
function progressBarContent(pct)
	local accomplished = math.ceil(cruise.option.progressBarSize * pct / 100)
	local left = cruise.option.progressBarSize - accomplished
	local content = "<span style='background-color:#181;color:#181;'>" .. string.rep("-", accomplished) .. "</span>" ..
	"<span style='background-color:#fff;color:#fff;'>" .. string.rep("-", left) .. "</span>"
	return content
end

function setMessage(str)
	if input_table["message"] then
		input_table["message"]:set_text(str)
		dlg:update()
	end
end

function setError(mess)
	setMessage(error_tag(mess))
end

function success_tag(str)
	return "<span style='color:#181'><b>" ..
	lang["mess_success"] .. ":</b></span> " .. str .. ""
end

function error_tag(str)
	return "<span style='color:#B23'><b>" ..
	lang["mess_error"] .. ":</b></span> " .. str .. ""
end

--[[ Network utils ]]--
function get(url)
	local host, path = parse_url(url)
	local header = {
		"GET " .. path .. " HTTP/1.1",
		"Host: " .. host,
		"User-Agent: " .. cruise.conf.userAgentHTTP,
		"",
		""
	}
	local request = table.concat(header, "\r\n")

	local response
	local status, response = http_req(host, 80, request)

	if status == 200 then
		return response
	else
		return false, status, response
	end
end

function http_req(host, port, request)
	local fd = vlc.net.connect_tcp(host, port)
	if not fd then return false end
	local pollfds = { }

	pollfds[fd] = vlc.net.POLLIN
	vlc.net.send(fd, request)
	vlc.net.poll(pollfds)

	local chunk = vlc.net.recv(fd, 2048)
	local response = ""
	local headerStr, header, body
	local contentLength, status
	local pct = 0

	while chunk do
		response = response .. chunk
		if not header then
			headerStr, body = response:match("(.-\r?\n)\r?\n(.*)")
			if headerStr then
				response = body
				header = parse_header(headerStr)
				contentLength = tonumber(header["Content-Length"])
				status = tonumber(header["statuscode"])
			end
		end

		if contentLength then
			bodyLenght = #response
			pct = bodyLenght / contentLength * 100
			setMessage(cruise.actionLabel .. ": " .. progressBarContent(pct))
			if bodyLenght >= contentLength then
				break
			end
		end

		vlc.net.poll(pollfds)
		chunk = vlc.net.recv(fd, 1024)
	end

	vlc.net.close(fd)

	if status == 301
		and header["Location"] then
		local host, path = parse_url(trim(header["Location"]))
		request = request
		:gsub("^([^%s]+ )([^%s]+)", "%1" .. path)
		:gsub("(Host: )([^\n]*)", "%1" .. host)

		return http_req(host, port, request)
	end

	return status, response
end

function parse_header(data)
	local header = { }

	for name, s, val in string.gmatch(data, "([^%s:]+)(:?)%s([^\n]+)\r?\n") do
		if s == "" then
			header['statuscode'] = tonumber(string.sub(val, 1, 3))
		else
			header[name] = val
		end
	end
	return header
end 

function parse_url(url)
	local url_parsed = vlc.net.url_parse(url)
	return url_parsed["host"],
	url_parsed["path"],
	url_parsed["option"]
end

--[[ XML utils ]]--
function parse_xml(data)
	local tree = { }
	local stack = { }
	local tmp = { }
	local level = 0
	local op, tag, p, empty, val
	table.insert(stack, tree)
	local resolve_xml = vlc.strings.resolve_xml_special_chars

	for op, tag, p, empty, val in string.gmatch(data, "[%s\r\n\t]*<(%/?)([%w:_]+)(.-)(%/?)>[%s\r\n\t]*([^<]*)[%s\r\n\t]*") do
		if op == "/" then
			if level > 0 then
				level = level - 1
				table.remove(stack)
			end
		else
			level = level + 1
			if val == "" then
				if type(stack[level][tag]) == "nil" then
					stack[level][tag] = { }
					table.insert(stack, stack[level][tag])
				else
					if type(stack[level][tag][1]) == "nil" then
						tmp = nil
						tmp = stack[level][tag]
						stack[level][tag] = nil
						stack[level][tag] = { }
						table.insert(stack[level][tag], tmp)
					end
					tmp = nil
					tmp = { }
					table.insert(stack[level][tag], tmp)
					table.insert(stack, tmp)
				end
			else
				if type(stack[level][tag]) == "nil" then
					stack[level][tag] = { }
				end
				stack[level][tag] = resolve_xml(val)
				table.insert(stack, { })
			end
			if empty ~= "" then
				stack[level][tag] = ""
				level = level - 1
				table.remove(stack)
			end
		end
	end

	collectgarbage()
	return tree
end

function parse_xmlrpc(data)
	local tree = { }
	local stack = { }
	local tmp = { }
	local tmpTag = ""
	local level = 0
	local op, tag, p, empty, val
	local resolve_xml = vlc.strings.resolve_xml_special_chars
	table.insert(stack, tree)

	for op, tag, p, empty, val in string.gmatch(data, "<(%/?)([%w:]+)(.-)(%/?)>[%s\r\n\t]*([^<]*)") do
		if op == "/" then
			if tag == "member" or tag == "array" then
				if level > 0 then
					level = level - 1
					table.remove(stack)
				end
			end
		elseif tag == "name" then
			level = level + 1
			if val ~= "" then tmpTag = resolve_xml(val) end

			if type(stack[level][tmpTag]) == "nil" then
				stack[level][tmpTag] = { }
				table.insert(stack, stack[level][tmpTag])
			else
				tmp = nil
				tmp = { }
				table.insert(stack[level - 1], tmp)

				stack[level] = nil
				stack[level] = tmp
				table.insert(stack, tmp)
			end
			if empty ~= "" then
				level = level - 1
				stack[level][tmpTag] = ""
				table.remove(stack)
			end
		elseif tag == "array" then
			level = level + 1
			tmp = nil
			tmp = { }
			table.insert(stack[level], tmp)
			table.insert(stack, tmp)
		elseif val ~= "" then
			stack[level][tmpTag] = resolve_xml(val)
		end
	end
	collectgarbage()
	return tree
end

function dump_xml(data)
	local level = 0
	local stack = { }
	local dump = ""
	local convert_xml = vlc.strings.convert_xml_special_chars

	local function parse(data, stack)
		local data_index = { }
		local k
		local v
		local i
		local tb

		for k, v in pairs(data) do
			table.insert(data_index, { k, v })
			table.sort(data_index, function(a, b)
				return a[1] < b[1]
			end )
		end

		for i, tb in pairs(data_index) do
			k = tb[1]
			v = tb[2]
			if type(k) == "string" then
				dump = dump .. "\r\n" .. string.rep(
				" ",
				level) ..
				"<" .. k .. ">"
				table.insert(stack, k)
				level = level + 1
			elseif type(k) == "number" and k ~= 1 then
				dump = dump .. "\r\n" .. string.rep(
				" ",
				level - 1) ..
				"<" .. stack[level] .. ">"
			end

			if type(v) == "table" then
				parse(v, stack)
			elseif type(v) == "string" then
				dump = dump ..(convert_xml(v) or v)
			elseif type(v) == "number" then
				dump = dump .. v
			else
				dump = dump .. tostring(v)
			end

			if type(k) == "string" then
				if type(v) == "table" then
					dump = dump .. "\r\n" .. string.rep(
					" ",
					level - 1) ..
					"</" .. k .. ">"
				else
					dump = dump .. "</" .. k .. ">"
				end
				table.remove(stack)
				level = level - 1

			elseif type(k) == "number" and k ~= #data then
				if type(v) == "table" then
					dump = dump .. "\r\n" .. string.rep(
					" ",
					level - 1) ..
					"</" .. stack[level] .. ">"
				else
					dump = dump .. "</" .. stack[level] .. ">"
				end
			end
		end
	end
	parse(data, stack)
	collectgarbage()
	return dump
end

--[[ Misc utils ]]--
function make_uri(str)
	str = str:gsub("\\", "/")
	local windowdrive = string.match(str, "^(%a:).+$")
	local encode_uri = vlc.strings.encode_uri_component
	local encodedPath = ""
	for w in string.gmatch(str, "/([^/]+)") do
		encodedPath = encodedPath .. "/" .. encode_uri(w)
	end

	if windowdrive then
		return "file:///" .. windowdrive .. encodedPath
	else
		return "file://" .. encodedPath
	end
end

function file_touch(name)
	-- test write ability
	if not name or trim(name) == ""
	then
		return false
	end

	local f = io.open(name, "w")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

function file_exist(name)
	-- test readability
	if not name or trim(name) == ""
	then
		return false
	end
	local f = io.open(name, "r")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

function is_dir(path)
	if not path or trim(path) == ""
	then
		return false
	end
	-- Remove slash at the end or it won't work on Windows
	path = string.gsub(path, "^(.-)[\\/]?$", "%1")
	local f, _, code = io.open(path, "rb")

	if f then
		_, _, code = f:read("*a")
		f:close()
		if code == 21 then
			return true
		end
	elseif code == 13 then
		return true
	end

	return false
end

function list_dir(path)
	if not path or trim(path) == ""
	then
		return false
	end
	local dir_list_cmd
	local list = { }
	if not is_dir(path) then return false end

	if cruise.conf.os == "win" then
		dir_list_cmd = io.popen('dir /b "' .. path .. '"')
	elseif cruise.conf.os == "lin" then
		dir_list_cmd = io.popen('ls -1 "' .. path .. '"')
	end

	if dir_list_cmd then
		for filename in dir_list_cmd:lines() do
			if string.match(filename, "^[^%s]+.+$") then
				table.insert(list, filename)
			end
		end
		return list
	else
		return false
	end
end

function mkdir_p(path)
	if not path or trim(path) == ""
	then
		return false
	end
	if cruise.conf.os == "win" then
		os.execute('mkdir "' .. path .. '"')
	elseif cruise.conf.os == "lin" then
		os.execute("mkdir -p '" .. path .. "'")
	end
end

function decode_uri(str)
	vlc.msg.err(slash)
	return str:gsub("/", slash)
end

function is_window_path(path)
	return string.match(path, "^(%a:.+)$")
end

function is_win_safe(path)
	if not path or trim(path) == ""
		or not is_window_path(path)
	then
		return false
	end
	return string.match(path, "^%a?%:?[\\%w%p%s§¤]+$")
end
    
function trim(str)
	if not str then return "" end
	return string.gsub(str, "^[\r\n%s]*(.-)[\r\n%s]*$", "%1")
end

function remove_tag(str)
	return string.gsub(str, "{[^}]+}", "")
end