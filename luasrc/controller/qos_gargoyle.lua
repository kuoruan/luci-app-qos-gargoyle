-- Copyright 2017 Xingwang Liao <kuoruan@gmail.com>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.qos_gargoyle", package.seeall)

local uci  = require "luci.model.uci".cursor()
local sys  = require "luci.sys"
local util = require "luci.util"
local http = require "luci.http"

local dpi_protocols = {}

function index()
	if not nixio.fs.access("/etc/config/qos_gargoyle") then
		return
	end

	entry({"admin", "network", "qos_gargoyle"},
		firstchild(), _("Gargoyle QoS"), 60)

	entry({"admin", "network", "qos_gargoyle", "global"},
		cbi("qos_gargoyle/global"), _("Global Settings"), 10)

	entry({"admin", "network", "qos_gargoyle", "upload"},
		cbi("qos_gargoyle/upload"), _("Upload Settings"), 20)

	entry({"admin", "network", "qos_gargoyle", "upload", "class"},
		cbi("qos_gargoyle/upload_class")).leaf = true

	entry({"admin", "network", "qos_gargoyle", "upload", "rule"},
		cbi("qos_gargoyle/upload_rule")).leaf = true

	entry({"admin", "network", "qos_gargoyle", "download"},
		cbi("qos_gargoyle/download"), _("Download Settings"), 30)

	entry({"admin", "network", "qos_gargoyle", "download", "class"},
		cbi("qos_gargoyle/download_class")).leaf = true

	entry({"admin", "network", "qos_gargoyle", "download", "rule"},
		cbi("qos_gargoyle/download_rule")).leaf = true

	entry({"admin", "network", "qos_gargoyle", "troubleshooting"},
		template("qos_gargoyle/troubleshooting"), _("Troubleshooting"), 40)

	entry({"admin", "network", "qos_gargoyle", "troubleshooting", "data"},
		call("action_troubleshooting_data"))
end

function has_ndpi()
	return sys.call("lsmod | cut -d ' ' -f1 | grep -q 'xt_ndpi'") == 0
end

local function init_dpi_protocols()
	for line in util.execi("iptables -m ndpi --help 2>/dev/null | grep '^--'") do
		local _, _, protocol, name = line:find("%-%-([^%s]+) Match for ([^%s]+)")

		if protocol and name then
			dpi_protocols[protocol] = name
		end
	end
end

function cbi_add_dpi_protocols(field)
	if #dpi_protocols == 0 then init_dpi_protocols() end

	for p, n in util.kspairs(dpi_protocols) do
		field:value(p, n)
	end
end

function action_troubleshooting_data()
	local data = {}

	local show_data = util.trim(util.exec("/etc/init.d/qos_gargoyle show 2>/dev/null"))
	if show_data == "" then
		show_data = "No data found"
	end

	data.show = show_data

	local monenabled = uci:get_first("qos_gargoyle", "download", "qos_monenabled")

	local mon_data
	if monenabled == "true" then
		mon_data = util.trim(util.exec("cat /tmp/qosmon.status 2>/dev/null"))

		if mon_data == "" then
			mon_data = "No data found"
		end
	else
		mon_data = "\"Active Congestion Control\" not enabled"
	end

	data.mon = mon_data

	http.prepare_content("application/json")
	http.write_json(data)
end
