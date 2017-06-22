--[[
luci for Gargoyle QoS
Based on GuoGuo's luci-app-qos-guoguo
Copyright (c) 2017 Xingwang Liao <kuoruan@gmail.com>
]]--

local uci  = require "luci.model.uci".cursor()
local dsp  = require "luci.dispatcher"
local http = require "luci.http"

local m, s, o
local download_classes = {}
local qos_gargoyle     = "qos_gargoyle"
local class_url        = dsp.build_url("admin/network/qos_gargoyle/download/class/%s")
local rule_url         = dsp.build_url("admin/network/qos_gargoyle/download/rule/%s")

uci:foreach(qos_gargoyle, "download_class", function(s)
	local class_alias = s.name
	if class_alias then
		download_classes[#download_classes + 1] = {name = s[".name"], alias = class_alias}
	end
end)

local function get_addr(ip, port)
	if ip and port then
		return "%s: %s<br>%s: %s" % {translate("IP(s)"), ip, translate("Port(s)"), port}
	elseif ip then
		return ip
	elseif port then
		return "%s<br>%s: %s" % {translate("All IPs"), translate("Port(s)"), port}
	else
		return translate("All Address")
	end
end

m = Map(qos_gargoyle, translate("Download Settings"))
m:append(Template("qos_gargoyle/rules_list"))

s = m:section(TypedSection, "download_class", translate("Service Classes"),
	translate("Each service class is specified by four parameters: percent bandwidth at capacity, "
	.. "realtime bandwidth and maximum bandwidth and the minimimze round trip time flag."))
s.anonymous = true
s.addremove = true
s.template  = "cbi/tblsection"
s.extedit   = class_url
s.create    = function(...)
	local sid = TypedSection.create(...)
	if sid then
		http.redirect(class_url % sid)
		return
	end
end

o = s:option(DummyValue, "name", translate("Class Name"))
o.cfgvalue = function(...)
	return Value.cfgvalue(...) or translate("None")
end

o = s:option(DummyValue, "percent_bandwidth", translate("Percent Bandwidth At Capacity"))
o.cfgvalue = function(...)
	local v = Value.cfgvalue(...)
	return v and v .. "%" or translate("Not set")
end

o = s:option(DummyValue, "min_bandwidth", translate("Minimum Bandwidth"))
o.cfgvalue = function(...)
	local v = Value.cfgvalue(...)
	return v and v .. " kbit/s" or translate("None")
end

o = s:option(DummyValue, "max_bandwidth", translate("Maximum Bandwidth"))
o.cfgvalue = function(...)
	local v = Value.cfgvalue(...)
	return v and v .. " kbit/s" or translate("Unlimited")
end

o = s:option(DummyValue, "minRTT", translate("Minimize RTT"))
o.cfgvalue = function(...)
	local v = Value.cfgvalue(...)
	return v and translate(v) or translate("No")
end

s = m:section(TypedSection, "download_rule", translate("Classification Rules"),
	translate("Packets are tested against the rules in the order specified -- rules toward the top "
	.. "have priority. As soon as a packet matches a rule it is classified, and the rest of the rules "
	.. "are ignored. The order of the rules can be altered using the arrow controls.")
	)
s.addremove = true
s.sortable  = true
s.anonymous = true
s.template  = "cbi/tblsection"
s.extedit   = rule_url
s.create    = function(...)
	local sid = TypedSection.create(...)
	if sid then
		http.redirect(rule_url % sid)
		return
	end
end

o = s:option(ListValue, "class", translate("Service Class"))
for _, s in ipairs(download_classes) do o:value(s.name, s.alias) end

o = s:option(Value, "proto", translate("Transport Protocol"))
o:value("", translate("All"))
o:value("tcp", "TCP")
o:value("udp", "UDP")
o:value("icmp", "ICMP")
o:value("gre", "GRE")
o.size = "10"
o.write = function(self, section, value)
	Value.write(self, section, value:lower())
end

o = s:option(DummyValue, "_srcaddr", translate("Source Address"))
o.rawhtml  = true
o.cfgvalue = function(self, section)
	local source_ip = self.map:get(section, "source")
	local source_port = self.map:get(section, "srcport")
	return get_addr(source_ip, source_port)
end

o = s:option(DummyValue, "_desaddr", translate("Destination Address"))
o.rawhtml  = true
o.cfgvalue = function(self, section)
	local destination_ip = self.map:get(section, "destination")
	local destination_port = self.map:get(section, "dstport")
	return get_addr(destination_ip, destination_port)
end

o = s:option(DummyValue, "min_pkt_size", translate("Minimum Packet Length"))
o.cfgvalue = function(...)
	local v = Value.cfgvalue(...)
	return v and v .. " B" or translate("Not set")
end

o = s:option(DummyValue, "max_pkt_size", translate("Maximum Packet Length"))
o.cfgvalue = function(...)
	local v = Value.cfgvalue(...)
	return v and v .. " B" or translate("Not set")
end

o = s:option(DummyValue, "connbytes_kb", translate("Connection Bytes Reach"))
o.cfgvalue = function(...)
	local v = Value.cfgvalue(...)
	return v and v .. " KB" or translate("Not set")
end

return m
