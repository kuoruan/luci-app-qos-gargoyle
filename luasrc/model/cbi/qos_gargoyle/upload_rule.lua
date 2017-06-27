--[[
luci for Gargoyle QoS
Copyright (c) 2017 Xingwang Liao <kuoruan@gmail.com>
]]--

local wa  = require "luci.tools.webadmin"
local uci = require "luci.model.uci".cursor()

local m, s, o
local sid = arg[1]
local upload_classes = {}
local qos_gargoyle = "qos_gargoyle"

uci:foreach(qos_gargoyle, "upload_class", function(s)
	local class_alias = s.name
	if class_alias then
		upload_classes[#upload_classes + 1] = {name = s[".name"], alias = class_alias}
	end
end)

local function has_ndpi()
	return luci.sys.call("lsmod | cut -d' ' -f1 | grep -q 'xt_ndpi'") == 0
end

m = Map(qos_gargoyle, translate("Edit Upload Classification Rule"))
m.redirect = luci.dispatcher.build_url("admin/network/qos_gargoyle/upload")

if m.uci:get(qos_gargoyle, sid) ~= "upload_rule" then
	luci.http.redirect(m.redirect)
	return
end

s = m:section(NamedSection, sid, "upload_rule")
s.anonymous = true
s.addremove = false

o = s:option(ListValue, "class", translate("Service Class"))
for _, s in ipairs(upload_classes) do o:value(s.name, s.alias) end

o = s:option(Value, "proto", translate("Transport Protocol"))
o:value("", translate("All"))
o:value("tcp", "TCP")
o:value("udp", "UDP")
o:value("icmp", "ICMP")
o:value("gre", "GRE")
o.write = function(self, section, value)
	Value.write(self, section, value:lower())
end

o = s:option(Value, "source", translate("Source IP(s)"),
	translate("Packet's source ip, can optionally have /[mask] after it (see -s option in iptables "
	.. "man page)."))
o:value("", translate("All"))
wa.cbi_add_knownips(o)
o.datatype = "ipmask4"

o = s:option(Value, "srcport", translate("Source Port(s)"),
	translate("Packet's source port, can be a range (eg. 80-90)."))
o:value("", translate("All"))
o.datatype  = "or(port, portrange)"

o = s:option(Value, "destination", translate("Destination IP(s)"),
	translate("Packet's destination ip, can optionally have /[mask] after it (see -d option in "
	.. "iptables man page)."))
o:value("", translate("All"))
wa.cbi_add_knownips(o)
o.datatype = "ipmask4"

o = s:option(Value, "dstport", translate("Destination Port(s)"),
	translate("Packet's destination port, can be a range (eg. 80-90)."))
o:value("", translate("All"))
o.datatype  = "or(port, portrange)"

o = s:option(Value, "min_pkt_size", translate("Minimum Packet Length"),
	translate("Packet's minimum size (in bytes)."))
o.datatype = "and(uinteger, min(1))"

o = s:option(Value, "max_pkt_size", translate("Maximum Packet Length"),
	translate("Packet's maximum size (in bytes)."))
o.datatype = "and(uinteger, min(1))"

o = s:option(Value, "connbytes_kb", translate("Connection Bytes Reach"),
	translate("The total size of data transmitted since the establishment of the link (in Kbytes)."))
o.datatype = "uinteger"

if has_ndpi() then
	o = s:option(ListValue, "ndpi", translate("DPI Protocol"))
	local pats = io.popen("iptables -m ndpi --help | grep -e '^--'")
	if pats then
		local l, s, e, prt_v, prt_d
		while true do
			l = pats:read("*l")
			if not l then break end
			s, e = l:find("%-%-[^%s]+")
			if s and e then
				prt_v = l:sub(s + 2, e)
			end
			s, e = l:find("for [^%s]+ protocol")
			if s and e then
				prt_d = l:sub(s + 3, e - 9)
			end
			o:value(prt_v, prt_d)
		end
		pats:close()
	end
end

return m
