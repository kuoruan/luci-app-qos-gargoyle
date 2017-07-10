--[[
luci for Gargoyle QoS
Based on GuoGuo's luci-app-qos-guoguo
Copyright (c) 2017 Xingwang Liao <kuoruan@gmail.com>
]]--

local wa   = require "luci.tools.webadmin"
local uci  = require "luci.model.uci".cursor()
local dsp  = require "luci.dispatcher"
local http = require "luci.http"

local m, class_s, rule_s, o
local download_classes = {}
local qos_gargoyle     = "qos_gargoyle"

uci:foreach(qos_gargoyle, "download_class", function(s)
	local class_alias = s.name
	if class_alias then
		download_classes[#download_classes + 1] = {name = s[".name"], alias = class_alias}
	end
end)

m = Map(qos_gargoyle, translate("Download Settings"))
m:append(Template("qos_gargoyle/rules_list"))

class_s = m:section(TypedSection, "download_class", translate("Service Classes"),
	translate("Each service class is specified by four parameters: percent bandwidth at capacity, "
	.. "realtime bandwidth and maximum bandwidth and the minimimze round trip time flag."))
class_s.anonymous = true
class_s.addremove = true
class_s.template  = "cbi/tblsection"
class_s.extedit   = dsp.build_url("admin/network/qos_gargoyle/download/class/%s")
class_s.create    = function(...)
	local sid = TypedSection.create(...)
	if sid then
		http.redirect(class_s.extedit % sid)
		return
	end
end

o = class_s:option(DummyValue, "name", translate("Class Name"))
o.cfgvalue = function(...)
	return Value.cfgvalue(...) or translate("None")
end

o = class_s:option(DummyValue, "percent_bandwidth", translate("Percent Bandwidth At Capacity"))
o.cfgvalue = function(...)
	local v = Value.cfgvalue(...)
	return v and v .. "%" or translate("Not set")
end

o = class_s:option(DummyValue, "min_bandwidth", translate("Minimum Bandwidth"))
o.cfgvalue = function(...)
	local v = Value.cfgvalue(...)
	return v and v .. " kbit/s" or translate("None")
end

o = class_s:option(DummyValue, "max_bandwidth", translate("Maximum Bandwidth"))
o.cfgvalue = function(...)
	local v = Value.cfgvalue(...)
	return v and v .. " kbit/s" or translate("Unlimited")
end

o = class_s:option(DummyValue, "minRTT", translate("Minimize RTT"))
o.cfgvalue = function(...)
	local v = Value.cfgvalue(...)
	return v and translate(v) or translate("No")
end

rule_s = m:section(TypedSection, "download_rule", translate("Classification Rules"),
	translate("Packets are tested against the rules in the order specified -- rules toward the top "
	.. "have priority. As soon as a packet matches a rule it is classified, and the rest of the rules "
	.. "are ignored. The order of the rules can be altered using the arrow controls.")
	)
rule_s.addremove = true
rule_s.sortable  = true
rule_s.anonymous = true
rule_s.template  = "cbi/tblsection"
rule_s.extedit   = dsp.build_url("admin/network/qos_gargoyle/download/rule/%s")
rule_s.create    = function(...)
	local sid = TypedSection.create(...)
	if sid then
		http.redirect(rule_s.extedit % sid)
		return
	end
end

o = rule_s:option(ListValue, "class", translate("Service Class"))
for _, s in ipairs(download_classes) do o:value(s.name, s.alias) end

o = rule_s:option(Value, "proto", translate("Transport Protocol"))
o:value("", translate("All"))
o:value("tcp", "TCP")
o:value("udp", "UDP")
o:value("icmp", "ICMP")
o:value("gre", "GRE")
o.size = "10"
o.cfgvalue = function(...)
	local v = Value.cfgvalue(...)
	return v and v:upper() or ""
end
o.write = function(self, section, value)
	Value.write(self, section, value:lower())
end

o = rule_s:option(Value, "source", translate("Source IP(s)"))
o:value("", translate("All"))
wa.cbi_add_knownips(o)
o.datatype = "ipmask4"

o = rule_s:option(Value, "srcport", translate("Source Port(s)"))
o:value("", translate("All"))
o.datatype  = "or(port, portrange)"

o = rule_s:option(Value, "destination", translate("Destination IP(s)"))
o:value("", translate("All"))
wa.cbi_add_knownips(o)
o.datatype = "ipmask4"

o = rule_s:option(Value, "dstport", translate("Destination Port(s)"))
o:value("", translate("All"))
o.datatype  = "or(port, portrange)"

o = rule_s:option(DummyValue, "min_pkt_size", translate("Minimum Packet Length"))
o.cfgvalue = function(...)
	local v = Value.cfgvalue(...)
	return v and v .. " B" or translate("Not set")
end

o = rule_s:option(DummyValue, "max_pkt_size", translate("Maximum Packet Length"))
o.cfgvalue = function(...)
	local v = Value.cfgvalue(...)
	return v and v .. " B" or translate("Not set")
end

o = rule_s:option(DummyValue, "connbytes_kb", translate("Connection Bytes Reach"))
o.cfgvalue = function(...)
	local v = Value.cfgvalue(...)
	return v and v .. " KB" or translate("Not set")
end

return m
