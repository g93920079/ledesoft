#!/bin/sh
#--------------------------------------------------------------------------------------
# Variable definitions
export KSROOT=/koolshare
source $KSROOT/scripts/base.sh
source $KSROOT/bin/helper.sh
eval `dbus export ss`
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
DNS_PORT=7913
CONFIG_FILE=$KSROOT/ss/ss.json
game_on=`dbus list ss_acl_mode|cut -d "=" -f 2 | grep 3`
[ -n "$game_on" ] || [ "$ss_basic_mode" == "3" ] && mangle=1
#lan_ipaddr=`awk "/config interface 'lan'/,/^$/ {print $1}" /etc/config/network | grep ipaddr |awk '{print $3}' |sed "s/'//g"`
lan_ipaddr=`uci get network.lan.ipaddr`
ip_prefix_hex=`echo $lan_ipaddr | awk -F "." '{printf ("0x%02x", $1)} {printf ("%02x", $2)} {printf ("%02x", $3)} {printf ("00/0xffffff00")}'`
LOCK_FILE=/var/lock/shadowsocks.lock
ISP_DNS1=`cat /tmp/resolv.conf.auto|cut -d " " -f 2|grep -v 0.0.0.0|grep -v 127.0.0.1|sed -n 2p`
ISP_DNS2=`cat /tmp/resolv.conf.auto|cut -d " " -f 2|grep -v 0.0.0.0|grep -v 127.0.0.1|sed -n 3p`
IFIP=`echo $ss_basic_server|grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:"`

# dns china
IFIP_DNS=`echo $ISP_DNS1|grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:"`
[ -n "$IFIP_DNS" ] && CDN="$ISP_DNS1" || CDN="114.114.114.114"
[ "$ss_dns_china" == "2" ] && CDN="223.5.5.5"
[ "$ss_dns_china" == "3" ] && CDN="223.6.6.6"
[ "$ss_dns_china" == "4" ] && CDN="114.114.114.114"
[ "$ss_dns_china" == "5" ] && CDN="114.114.115.115"
[ "$ss_dns_china" == "6" ] && CDN="1.2.4.8"
[ "$ss_dns_china" == "7" ] && CDN="210.2.4.8"
[ "$ss_dns_china" == "8" ] && CDN="112.124.47.27"
[ "$ss_dns_china" == "9" ] && CDN="114.215.126.16"
[ "$ss_dns_china" == "10" ] && CDN="180.76.76.76"
[ "$ss_dns_china" == "11" ] && CDN="119.29.29.29"
[ "$ss_dns_china" == "12" ] && CDN="$ss_dns_china_user"
# dns for foreign ss-tunnel
[ "$ss_sstunnel" == "1" ] && gs="208.67.220.220:53"
[ "$ss_sstunnel" == "2" ] && gs="8.8.8.8:53"
[ "$ss_sstunnel" == "3" ] && gs="8.8.4.4:53"
[ "$ss_sstunnel" == "4" ] && gs="$ss_sstunnel_user"	
# dns for pdnsd upstream ss-tunnel
[ "$ss_pdnsd_udp_server_ss_tunnel" == "1" ] && dns1="208.67.220.220:53"
[ "$ss_pdnsd_udp_server_ss_tunnel" == "2" ] && dns1="8.8.8.8:53"
[ "$ss_pdnsd_udp_server_ss_tunnel" == "3" ] && dns1="8.8.4.4:53"
[ "$ss_pdnsd_udp_server_ss_tunnel" == "4" ] && dns1="$ss_pdnsd_udp_server_ss_tunnel_user"
# dns for foreign dns: chinaDNS dns for china
[ "$ss_chinadns_china" == "1" ] && rcc="223.5.5.5"
[ "$ss_chinadns_china" == "2" ] && rcc="223.6.6.6"
[ "$ss_chinadns_china" == "3" ] && rcc="114.114.114.114"
[ "$ss_chinadns_china" == "4" ] && rcc="114.114.115.115"
[ "$ss_chinadns_china" == "5" ] && rcc="1.2.4.8"
[ "$ss_chinadns_china" == "6" ] && rcc="210.2.4.8"
[ "$ss_chinadns_china" == "7" ] && rcc="112.124.47.27"
[ "$ss_chinadns_china" == "8" ] && rcc="114.215.126.16"
[ "$ss_chinadns_china" == "9" ] && rcc="180.76.76.76"
[ "$ss_chinadns_china" == "10" ] && rcc="119.29.29.29"
[ "$ss_chinadns_china" == "11" ] && rcc="$ss_chinadns_china_user"
# dns for foreign dns: chinaDNS foreign dns:dns2socks
[ "$ss_chinadns_foreign_dns2socks" == "1" ] && rcfd="208.67.220.220:53"
[ "$ss_chinadns_foreign_dns2socks" == "2" ] && rcfd="8.8.8.8:53"
[ "$ss_chinadns_foreign_dns2socks" == "3" ] && rcfd="8.8.4.4:53"
[ "$ss_chinadns_foreign_dns2socks" == "4" ] && rcfd="$ss_chinadns_foreign_dns2socks_user"
# dns for foreign dns: chinaDNS foreign dns:ss-tunnel
[ "$ss_chinadns_foreign_sstunnel" == "1" ] && rcfs="208.67.220.220:53"
[ "$ss_chinadns_foreign_sstunnel" == "2" ] && rcfs="8.8.8.8:53"
[ "$ss_chinadns_foreign_sstunnel" == "3" ] && rcfs="8.8.4.4:53"
[ "$ss_chinadns_foreign_sstunnel" == "4" ] && rcfs="$ss_chinadns_foreign_sstunnel_user"
# ==========================================================================================
# stop first
redsocks2=$(ps | grep "redsocks2" | grep -v "grep")
dnscrypt=$(ps | grep "dnscrypt-proxy" | grep -v "grep")
ssredir=$(ps | grep "ss-redir" | grep -v "grep" | grep -vw "ssr-redir")
ssrredir=$(ps | grep "ssr-redir" | grep -v "grep" | grep -vw "ss-redir")
sstunnel=$(ps | grep "ss-tunnel" | grep -v "grep" | grep -vw "ssr-tunnel")
ssrtunnel=$(ps | grep "ssr-tunnel" | grep -v "grep" | grep -vw "ss-tunnel")
pdnsd=$(ps | grep "pdnsd" | grep -v "grep")
chinadns=$(ps | grep "chinadns" | grep -v "grep")
DNS2SOCK=$(ps | grep "dns2socks" | grep -v "grep")
Pcap_DNSProxy=$(ps | grep "Pcap_DNSProxy" | grep -v "grep")
HAPID=`pidof haproxy`
ip_rule_exist=`/usr/sbin/ip rule show | grep "fwmark 0x1/0x1 lookup 310" | grep -c 310`
#--------------------------------------------------------------------------
restore_dnsmasq_conf(){
	# delete server setting in dnsmasq.conf
	pc_delete "server=" "/etc/dnsmasq.conf"
	pc_delete "all-servers" "/etc/dnsmasq.conf"
	pc_delete "no-resolv" "/etc/dnsmasq.conf"
	pc_delete "no-poll" "/etc/dnsmasq.conf"

	# delete custom.conf
	if [ -f /tmp/dnsmasq.d/custom.conf ];then
		echo_date 删除 /tmp/dnsmasq.d/custom.conf
		rm -rf /tmp/dnsmasq.d/custom.conf
	fi
	echo_date 删除ss相关的名单配置文件.
	# remove conf under /jffs/etc/dnsmasq.d
	rm -rf /tmp/dnsmasq.d/gfwlist.conf
	rm -rf /tmp/dnsmasq.d/output.conf
	rm -rf /tmp/dnsmasq.d/cdn.conf
	rm -rf /tmp/dnsmasq.d/sscdn.conf
	rm -rf /tmp/dnsmasq.d/custom.conf
	rm -rf /tmp/dnsmasq.d/wblist.conf
	rm -rf /tmp/dnsmasq.d/ssserver.conf
	rm -rf /tmp/sscdn.conf
	rm -rf /tmp/custom.conf
	rm -rf /tmp/wblist.conf
}

restore_start_file(){
	echo_date 清除nat-start, wan-start中相关的SS启动命令...
	rm -rf /etc/rc.d/S99shadowsocks.sh  >/dev/null 2>&1
	
	uci -q batch <<-EOT
	  delete firewall.ks_shadowsocks
	  commit firewall
	EOT
}

kill_process(){
	#--------------------------------------------------------------------------
	# kill dnscrypt-proxy
	if [ -n "$dnscrypt" ]; then 
		echo_date 关闭dnscrypt-proxy进程...
		killall dnscrypt-proxy
	fi
	# kill redsocks2
	if [ -n "$redsocks2" ]; then 
		echo_date 关闭redsocks2进程...
		killall redsocks2
	fi
	# kill ss-redir
	if [ -n "$ssredir" ];then 
		echo_date 关闭ss-redir进程...
		killall ss-redir
	fi
	if [ -n "$ssrredir" ];then 
		echo_date 关闭ssr-redir进程...
		killall ssr-redir
	fi
	# kill ss-local
	sslocal=`ps | grep ss-local | grep -v "grep" | grep -w "23456" | awk '{print $1}'`
	if [ -n "$sslocal" ];then 
		echo_date 关闭ss-local进程:23456端口...
		kill -9 $sslocal  >/dev/null 2>&1
	fi
	ssrlocal=`ps | grep ssr-local | grep -v "grep" | grep -w "23456" | awk '{print $1}'`
	if [ -n "$ssrlocal" ];then 
		echo_date 关闭ssr-local进程:23456端口...
		kill -9 $ssrlocal  >/dev/null 2>&1
	fi
	# kill ss-tunnel
	if [ -n "$sstunnel" ];then 
		echo_date 关闭ss-tunnel进程...
		killall ss-tunnel
	fi
	if [ -n "$ssrtunnel" ];then 
		echo_date 关闭ssr-tunnel进程...
		killall ssr-tunnel
	fi
	# kill pdnsd
	if [ -n "$pdnsd" ];then 
		echo_date 关闭pdnsd进程...
		killall pdnsd
	fi
	# kill Pcap_DNSProxy
	if [ -n "$Pcap_DNSProxy" ];then 
		echo_date 关闭Pcap_DNSProxy进程...
		killall Pcap_DNSProxy >/dev/null 2>&1
	fi
	# kill chinadns
	if [ -n "$chinadns" ];then 
		echo_date 关闭chinadns进程...
		kill -9 `pidof chinadns`
	fi
	# kill dns2socks
	if [ -n "$DNS2SOCK" ];then 
		echo_date 关闭dns2socks进程...
		killall dns2socks
	fi
	# kill haproxy
	if [ -n "`pidof haproxy`" ];then
		echo_date 关闭haproxy进程...
		killall haproxy
	fi
	# kill kcptun
	if [ -n "`pidof kcpclient`" ];then
		echo_date 关闭haproxy进程...
		killall kcpclient
	fi
}

kill_cron_job(){
	echo_date 删除ss规则定时更新任务.
	sed -i '/ssupdate/d' /etc/crontabs/root >/dev/null 2>&1 &
}

# ==========================================================================================
# try to resolv the ss server ip if it is domain...
resolv_server_ip(){
	if [ -z "$IFIP" ];then
		echo_date 使用nslookup方式解析服务器的ip地址,解析dns：$ss_basic_dnslookup_server
		if [ "$ss_basic_dnslookup" == "1" ];then
			server_ip=`nslookup "$ss_basic_server" $ss_basic_dnslookup_server | sed '1,4d' | awk '{print $3}' | grep -v :|awk 'NR==1{print}'`
		else
			echo_date 使用resolveip方式解析服务器的ip地址.
			server_ip=`resolveip -4 -t 2 $ss_basic_server|awk 'NR==1{print}'`
		fi

		if [ -n "$server_ip" ];then
			echo_date 服务器的ip地址解析成功：$server_ip.
			ss_basic_server="$server_ip"
			dbus set ss_basic_server_ip="$server_ip"
			ss_basic_server_ip="$server_ip"
			dbus set ss_basic_dns_success="1"
			# store resoved ip in skipd
			echo_date 将解析结果储存到skipd数据库...
			if [ "$ss_basic_type"  == "1" ];then
				dbus set ssrconf_basic_server_ip_$ss_basic_node="$server_ip"
			elif [ "$ss_basic_type"  == "0" ];then
				dbus set ssconf_basic_server_ip_$ss_basic_node="$server_ip"
			fi
		else
			# get pre-resoved ip in skipd
			echo_date 尝试获取上次储存的解析结果...
			if [ "$ss_basic_type"  == "1" ];then
				ss_basic_server=`dbus get ssrconf_basic_server_ip_$ss_basic_node`
			elif [ "$ss_basic_type"  == "0" ];then
				ss_basic_server=`dbus get ssconf_basic_server_ip_$ss_basic_node`
			fi
			[ -n "$ss_basic_server" ] && echo_date 成功获取到上次储存的解析结果：$ss_basic_server && dbus set ss_basic_dns_success="1"
			[ -z "$ss_basic_server" ] && ss_basic_server=`dbus get ss_basic_server` && echo_date SS服务器的ip地址解析失败，将由ss-redir自己解析. && dbus set ss_basic_dns_success="0"
		fi
	else
		echo_date 检测到你的SS服务器已经是IP格式：$ss_basic_server,跳过解析... 
		dbus set ss_basic_server_ip="$ss_basic_server"
		ss_basic_server_ip="$ss_basic_server"
		dbus set ss_basic_dns_success="1"
	fi
}

start_kcp(){
	# Start kcp
	if [ "$ss_kcp_enable" == "1" ] && [ "$ss_kcp_node" == "$ss_basic_node" ];then
		if [ "$ss_kcp_compon" == "1" ];then
			COMP="--nocomp"
		else
			COMP=""
		fi
		echo_date 启动KCPTUN.
		start-stop-daemon -S -q -b -m \
		-p /tmp/var/kcp.pid \
		-x /koolshare/bin/kcpclient \
		-- -l 127.0.0.1:11183 \
		-r $ss_kcp_server:$ss_kcp_port \
		--key $ss_kcp_password \
		--crypt $ss_kcp_crypt \
		--mode $ss_kcp_mode $ss_kcp_config \
		--conn $ss_kcp_conn \
		--mtu $ss_kcp_mtu \
		--sndwnd $ss_kcp_sndwnd \
		--rcvwnd $ss_kcp_rcvwnd \
		$COMP
	fi
}

# create shadowsocks config file...
creat_ss_json(){
	if [ "$ss_basic_ss_obfs_host" != "" ];then
		if [ "$ss_basic_ss_obfs" == "http" ];then
			ARG_OBFS="obfs=http;obfs-host=$ss_basic_ss_obfs_host"
		elif [ "$ss_basic_ss_obfs" == "tls" ];then
			ARG_OBFS="obfs=tls;obfs-host=$ss_basic_ss_obfs_host"
		else
			ARG_OBFS=""
		fi
	else
		if [ "$ss_basic_ss_obfs" == "http" ];then
			ARG_OBFS="obfs=http"
		elif [ "$ss_basic_ss_obfs" == "tls" ];then
			ARG_OBFS="obfs=tls"
		else
			ARG_OBFS=""
		fi
	fi
	if [ "$ss_kcp_enable" == "1" ] && [ "$ss_kcp_node" == "$ss_basic_node" ];then
		echo_date 创建SS配置文件到$CONFIG_FILE
		if [ "$ss_basic_type" == "0" ];then
			cat > $CONFIG_FILE <<-EOF
				{
				    "server":"127.0.0.1",
				    "server_port":11183,
				    "local_port":3333,
				    "password":"$ss_basic_password",
				    "timeout":600,
				    "method":"$ss_basic_method"
				}
			EOF
		elif [ "$ss_basic_type" == "1" ];then
			cat > $CONFIG_FILE <<-EOF
				{
				    "server":"127.0.0.1",
				    "server_port":11183,
				    "local_port":3333,
				    "password":"$ss_basic_password",
				    "timeout":600,
				    "protocol":"$ss_basic_rss_protocal",
				    "protocol_param":"$ss_basic_rss_protocal_para",
				    "obfs":"$ss_basic_rss_obfs",
				    "obfs_para":"$ss_basic_rss_obfs_para",
				    "method":"$ss_basic_method"
				}
			EOF
		fi
		start_kcp
	else
		echo_date 创建SS配置文件到$CONFIG_FILE
		if [ "$ss_basic_type" == "0" ];then
			cat > $CONFIG_FILE <<-EOF
				{
				    "server":"$ss_basic_server",
				    "server_port":$ss_basic_port,
				    "local_port":3333,
				    "password":"$ss_basic_password",
				    "timeout":600,
				    "method":"$ss_basic_method"
				}
			EOF
		elif [ "$ss_basic_type" == "1" ];then
			cat > $CONFIG_FILE <<-EOF
				{
				    "server":"$ss_basic_server",
				    "server_port":$ss_basic_port,
				    "local_port":3333,
				    "password":"$ss_basic_password",
				    "timeout":600,
				    "protocol":"$ss_basic_rss_protocal",
				    "protocol_param":"$ss_basic_rss_protocal_para",
				    "obfs":"$ss_basic_rss_obfs",
				    "obfs_para":"$ss_basic_rss_obfs_para",
				    "method":"$ss_basic_method"
				}
			EOF
		fi
	fi
}

start_haproxy(){
	echo_date 生成haproxy配置文件到/koolshare/configs目录.
	mkdir -p /koolshare/configs
	cat > /koolshare/configs/haproxy.cfg <<-EOF
		global
		    log         127.0.0.1 local2
		    chroot      /usr/bin
		    pidfile     /var/run/haproxy.pid
		    maxconn     4000
		    user        nobody
		    daemon
		defaults
		    mode                    tcp
		    log                     global
		    option                  tcplog
		    option                  dontlognull
		    option http-server-close
		    #option forwardfor      except 127.0.0.0/8
		    option                  redispatch
		    retries                 2
		    timeout http-request    10s
		    timeout queue           1m
		    timeout connect         3s                                   
		    timeout client          1m
		    timeout server          1m
		    timeout http-keep-alive 10s
		    timeout check           10s
		    maxconn                 3000
		listen admin_status
		    bind 0.0.0.0:1188
		    mode http                
		    stats refresh 30s    
		    stats uri  /
		    stats auth $ss_lb_account:$ss_lb_password
		    #stats hide-version  
		    stats admin if TRUE
		resolvers mydns
		    nameserver dns1 119.29.29.29:53
		    nameserver dns2 114.114.114.114:53
		    resolve_retries       3
		    timeout retry         2s
		    hold valid           10s
		listen shadowscoks_balance_load
		    bind 0.0.0.0:$ss_lb_port
		    mode tcp
		    balance roundrobin
	EOF
	
	if [ "ss_lb_type" == 1 ];then
		lb_node=`dbus list ssconf_basic_lb_enable|cut -d "=" -f 1| cut -d "_" -f 5 | sort -n | sed '/^$/d'`
	else
		lb_node=`dbus list ssrconf_basic_lb_enable|cut -d "=" -f 1| cut -d "_" -f 5 | sort -n | sed '/^$/d'`
	fi
	
	for node in $lb_node
	do
		up=`dbus get ss_lb_up`
		down=`dbus get ss_lb_down`
		interval=`dbus get ss_lb_interval`
		if [ "ss_lb_type" == 1 ];then
			nick_name=`dbus get ssconf_basic_name_$node`
			port=`dbus get ssconf_basic_port_$node`
			name=`dbus get ssconf_basic_server_$node`:$port
			server=`dbus get ssconf_basic_server_$node`
			weight=`dbus get ssconf_basic_lb_weight_$node`
			mode=`dbus get ssconf_basic_lb_policy_$node`
		else
			nick_name=`dbus get ssrconf_basic_name_$node`
			port=`dbus get ssrconf_basic_port_$node`
			name=`dbus get ssrconf_basic_server_$node`:$port
			server=`dbus get ssrconf_basic_server_$node`
			weight=`dbus get ssrconf_basic_lb_weight_$node`
			mode=`dbus get ssrconf_basic_lb_policy_$node`
		fi
		
		IFIP=`echo $server|grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:"`
		if [ -z "$IFIP" ];then
			echo_date 检测到【"$nick_name"】节点域名格式，将尝试进行解析...
			echo_date 尝试解析解析SS服务器的ip地址...
			server=`resolveip -4 -t 2 "$server"|awk 'NR==1{print}'`
			if [ -z "$server" ];then
				echo_date 解析失败，更换方案再次尝试！
				server=`nslookup "$server" localhost | sed '1,4d' | awk '{print $3}' | grep -v :|awk 'NR==1{print}'`
				if [ -n "$server" ];then
					echo_date 【"$nick_name"】节点ip地址解析成功：$server
					ipset -! add white_list $server >/dev/null 2>&1
				else
					echo_date 【"$nick_name"】节点ip解析失败，将由haproxy自己尝试解析.
					if [ "ss_lb_type" == 1 ];then
						server=`dbus get ssconf_basic_server_$node`
					else
						server=`dbus get ssrconf_basic_server_$node`
					fi
				fi
			else
				echo_date 【"$nick_name"】节点ip地址解析成功：$server
			fi
		else
			ipset -! add white_list $server >/dev/null 2>&1
			echo_date 检测到【"$nick_name"】节点已经是IP格式，跳过解析... 
		fi

		if [ "$mode" == "3" ];then
			echo_date 载入【"$nick_name"】作为备用节点...
			if [ "$ss_lb_heartbeat" == "1" ];then
				echo_date 启用故障转移心跳...
				cat >> /koolshare/configs/haproxy.cfg <<-EOF
				    server $name $server:$port weight $weight rise $up fall $down check inter $interval resolvers mydns backup
				EOF
			else
				echo_date 不启用故障转移心跳...
				cat >> /koolshare/configs/haproxy.cfg <<-EOF
				    server $name $server:$port weight $weight resolvers mydns backup
				EOF
			fi
		elif [ "$mode" == "2" ];then
			echo_date 载入【"$nick_name"】作为主用节点...
			if [ "$ss_lb_heartbeat" == "1" ];then
				echo_date 启用故障转移心跳...
				cat >> /koolshare/configs/haproxy.cfg <<-EOF
				    server $name $server:$port weight $weight check inter $interval rise $up fall $down resolvers mydns 
				EOF
			else
				echo_date 不启用故障转移心跳...
				cat >> /koolshare/configs/haproxy.cfg <<-EOF
				    server $name $server:$port weight $weight resolvers mydns 
				EOF
			fi
		else
			echo_date 载入【"$nick_name"】作为负载均衡节点...
			if [ "$ss_lb_heartbeat" == "1" ];then
				echo_date 启用故障转移心跳...
				cat >> /koolshare/configs/haproxy.cfg <<-EOF
				    server $name $server:$port weight $weight check inter $interval rise $up fall $down resolvers mydns 
				EOF
			else
				echo_date 不启用故障转移心跳...
				cat >> /koolshare/configs/haproxy.cfg <<-EOF
				    server $name $server:$port weight $weight resolvers mydns 
				EOF
			fi
		fi
	done

	if [ -z "`pidof haproxy`" ];then
		echo_date ┏启动haproxy主进程...
		echo_date ┣如果此处等待过久，可能服务器域名解析失败造成的！可以刷新页面后关闭一次SS!
		echo_date ┣然后进入附加设置-SS服务器地址解析，更改解析dns或者更换解析方式！
		echo_date ┗启动haproxy主进程...
		haproxy -f /koolshare/configs/haproxy.cfg
	fi
}

start_sslocal(){
	if [ "$ss_basic_type" == "1" ];then
		ssr-local -b 0.0.0.0 -l 23456 -c $CONFIG_FILE -u -f /var/run/sslocal1.pid >/dev/null 2>&1
	elif  [ "$ss_basic_type" == "0" ];then
		if [ "$ss_basic_ss_obfs" == "0" ];then
			ss-local -b 0.0.0.0 -l 23456 -c $CONFIG_FILE -u -f /var/run/sslocal1.pid >/dev/null 2>&1
		else
			ss-local -b 0.0.0.0 -l 23456 -c $CONFIG_FILE -u --plugin obfs-local --plugin-opts "$ARG_OBFS" -f /var/run/sslocal1.pid >/dev/null 2>&1
		fi
	fi
}

start_dns(){
	# Start DNS2SOCKS
	if [ "1" == "$ss_dns_foreign" ] || [ -z "$ss_dns_foreign" ]; then
		echo_date 开启ss-local，提供socks5端口：23456
		start_sslocal
		sleep 1
		echo_date 开启dns2socks，监听端口：23456
		dns2socks 127.0.0.1:23456 "$ss_dns2socks_user" 127.0.0.1:$DNS_PORT > /dev/null 2>&1 &
	fi

	# Start ss-tunnel
	if [ "2" == "$ss_dns_foreign" ];then
		if [ "$ss_basic_type" == "1" ];then
			echo_date 开启ssr-tunnel...
			ssr-tunnel -b 0.0.0.0 -s $ss_basic_server -p $ss_basic_port -c $CONFIG_FILE -l $DNS_PORT -L "$gs" -u -f /var/run/sstunnel.pid >/dev/null 2>&1
		elif  [ "$ss_basic_type" == "0" ];then
			echo_date 开启ss-tunnel...
			ss-tunnel -b 0.0.0.0 -s $ss_basic_server -p $ss_basic_port -c $CONFIG_FILE -l $DNS_PORT -L "$gs" -u -f /var/run/sstunnel.pid >/dev/null 2>&1
			if [ "$ss_basic_ss_obfs" == "0" ];then
				ss-tunnel -b 0.0.0.0 -s $ss_basic_server -p $ss_basic_port -c $CONFIG_FILE -l $DNS_PORT -L "$gs" -u -f /var/run/sstunnel.pid >/dev/null 2>&1
			else
				ss-tunnel -b 0.0.0.0 -s $ss_basic_server -p $ss_basic_port -c $CONFIG_FILE -l $DNS_PORT -L "$gs" -u --plugin obfs-local --plugin-opts "$ARG_OBFS" -f /var/run/sstunnel.pid >/dev/null 2>&1
			fi
		fi
	fi

	# Start dnscrypt-proxy
	if [ "3" == "$ss_dns_foreign" ] && [ "$ss_basic_enable" != "0" ];then
		echo_date 开启 dnscrypt-proxy，你选择了"$ss_opendns"节点.
		dnscrypt-proxy -a 127.0.0.1:$DNS_PORT -d -L $KSROOT/ss/rules/dnscrypt-resolvers.csv -R $ss_opendns >/dev/null 2>&1 &
	fi
	
	# Start pdnsd
	if [ "4" == "$ss_dns_foreign"  ]; then
		echo_date 开启 pdnsd，pdnsd进程可能会不稳定，请自己斟酌.
		echo_date 创建$KSROOT/ss/pdnsd文件夹.
		mkdir -p $KSROOT/ss/pdnsd
		if [ "$ss_pdnsd_method" == "1" ];then
			echo_date 创建pdnsd配置文件到$KSROOT/ss/pdnsd/pdnsd.conf
			echo_date 你选择了-仅udp查询-，需要开启上游dns服务，以防止dns污染.
			cat > $KSROOT/ss/pdnsd/pdnsd.conf <<-EOF
				global {
					perm_cache=2048;
					cache_dir="$KSROOT/ss/pdnsd/";
					run_as="root";
					server_port = $DNS_PORT;
					server_ip = 127.0.0.1;
					status_ctl = on;
					query_method=udp_only;
					min_ttl=$ss_pdnsd_server_cache_min;
					max_ttl=$ss_pdnsd_server_cache_max;
					timeout=10;
				}
				
				server {
					label= "LEDE-X64"; 
					ip = 127.0.0.1;
					port = 1099;
					root_server = on;   
					uptest = none;    
				}
				EOF
			if [ "$ss_pdnsd_udp_server" == "1" ];then
				echo_date 开启ss-local，提供socks5端口：23456
				start_sslocal
				echo_date 开启dns2socks作为pdnsd的上游服务器.
				dns2socks 127.0.0.1:23456 "$ss_pdnsd_udp_server_dns2socks" 127.0.0.1:1099 > /dev/null 2>&1 &
			elif [ "$ss_pdnsd_udp_server" == "2" ];then
				echo_date 开启dnscrypt-proxy作为pdnsd的上游服务器.
				dnscrypt-proxy --local-address=127.0.0.1:1099 --daemonize -L $KSROOT/ss/rules/dnscrypt-resolvers.csv -R "$ss_pdnsd_udp_server_dnscrypt"
			elif [ "$ss_pdnsd_udp_server" == "3" ];then
				if [ "$ss_basic_type" == "1" ];then
					echo_date 开启ssr-tunnel作为pdnsd的上游服务器.
					ssr-tunnel -b 0.0.0.0 -s $ss_basic_server -p $ss_basic_port -c $CONFIG_FILE -l 1099 -L "$dns1" -u -f /var/run/sstunnel.pid >/dev/null 2>&1
				elif  [ "$ss_basic_type" == "0" ];then
					echo_date 开启ss-tunnel作为pdnsd的上游服务器.
					if [ "$ss_basic_ss_obfs" == "0" ];then
						ss-tunnel -b 0.0.0.0 -s $ss_basic_server -p $ss_basic_port -c $CONFIG_FILE -l $DNS_PORT -L "$dns1" -u -f /var/run/sstunnel.pid >/dev/null 2>&1
					else
						ss-tunnel -b 0.0.0.0 -s $ss_basic_server -p $ss_basic_port -c $CONFIG_FILE -l $DNS_PORT -L "$dns1" -u --plugin obfs-local --plugin-opts "$ARG_OBFS" -f /var/run/sstunnel.pid >/dev/null 2>&1
					fi
				fi
			fi
		elif [ "$ss_pdnsd_method" == "2" ];then
			echo_date 创建pdnsd配置文件到$KSROOT/ss/pdnsd/pdnsd.conf
			echo_date 你选择了-仅tcp查询-，使用"$ss_pdnsd_server_ip":"$ss_pdnsd_server_port"进行tcp查询.
			cat > $KSROOT/ss/pdnsd/pdnsd.conf <<-EOF
				global {
					perm_cache=2048;
					cache_dir="$KSROOT/ss/pdnsd/";
					run_as="root";
					server_port = $DNS_PORT;
					server_ip = 127.0.0.1;
					status_ctl = on;
					query_method=tcp_only;
					min_ttl=$ss_pdnsd_server_cache_min;
					max_ttl=$ss_pdnsd_server_cache_max;
					timeout=10;
				}
				
				server {
					label= "RT-AC68U"; 
					ip = $ss_pdnsd_server_ip;
					port = $ss_pdnsd_server_port;
					root_server = on;   
					uptest = none;    
				}
				EOF
		fi
		
		chmod 644 $KSROOT/ss/pdnsd/pdnsd.conf
		CACHEDIR=$KSROOT/ss/pdnsd
		CACHE=$KSROOT/ss/pdnsd/pdnsd.cache
		USER=root
		GROUP=nogroup
	
		if ! test -f "$CACHE"; then
			echo_date 创建pdnsd缓存文件.
			dd if=/dev/zero of=$KSROOT/ss/pdnsd/pdnsd.cache bs=1 count=4 2> /dev/null
			chown -R $USER.$GROUP $CACHEDIR 2> /dev/null
		fi

		echo_date 启动pdnsd进程...
		pdnsd --daemon -c $KSROOT/ss/pdnsd/pdnsd.conf -p /var/run/pdnsd.pid
	fi

	# Start chinadns
	if [ "5" == "$ss_dns_foreign" ];then
		echo_date ┏ 你选择了chinaDNS作为解析方案！
		if [ "$ss_chinadns_foreign_method" == "1" ];then
			echo_date ┣ 开启ss-local,为dns2socks提供socks5端口：23456
			start_sslocal
			echo_date ┣ 开启dns2socks，作为chinaDNS上游国外dns，转发dns：$rcfd
			dns2socks 127.0.0.1:23456 "$rcfd" 127.0.0.1:1055 >/dev/null 2>&1 &
		elif [ "$ss_chinadns_foreign_method" == "2" ];then
			echo_date ┣ 开启 dnscrypt-proxy，作为chinaDNS上游国外dns，你选择了"$ss_chinadns_foreign_dnscrypt"节点.
			dnscrypt-proxy --local-address=127.0.0.1:1055 --daemonize -L $KSROOT/ss/rules/dnscrypt-resolvers.csv -R $ss_chinadns_foreign_dnscrypt >/dev/null 2>&1
		elif [ "$ss_chinadns_foreign_method" == "3" ];then
			if [ "$ss_basic_type" == "1" ];then
				echo_date ┣ 开启ssr-tunnel，作为chinaDNS上游国外dns，转发dns：$rcfs
				ssr-tunnel -b 127.0.0.1 -s $ss_basic_server -p $ss_basic_port -c $CONFIG_FILE -l 1055 -L "$rcfs" -u -f /var/run/sstunnel.pid >/dev/null 2>&1
			elif  [ "$ss_basic_type" == "0" ];then
				echo_date ┣ 开启ss-tunnel，作为chinaDNS上游国外dns，转发dns：$rcfs
				ss-tunnel -b 0.0.0.0 -s $ss_basic_server -p $ss_basic_port -c $CONFIG_FILE -l 1055 -L "$rcfs" -u -f /var/run/sstunnel.pid
				if [ "$ss_basic_ss_obfs" == "0" ];then
					ss-tunnel -b 0.0.0.0 -s $ss_basic_server -p $ss_basic_port -c $CONFIG_FILE -l 1055 -L "$rcfs" -u -f /var/run/sstunnel.pid >/dev/null 2>&1
				else
					ss-tunnel -b 0.0.0.0 -s $ss_basic_server -p $ss_basic_port -c $CONFIG_FILE -l 1055 -L "$rcfs" -u --plugin obfs-local --plugin-opts "$ARG_OBFS" -f /var/run/sstunnel.pid >/dev/null 2>&1
				fi
			fi
		elif [ "$ss_chinadns_foreign_method" == "4" ];then
			echo_date ┣ 你选择了自定义chinadns国外dns！dns：$ss_chinadns_foreign_method_user
		fi
		echo_date ┗ 开启chinadns进程！
		chinadns -p $DNS_PORT -s "$rcc",127.0.0.1:1055 -m -d -c $KSROOT/ss/rules/chnroute.txt  >/dev/null 2>&1 &
	fi
	
	# Start Pcap_DNSProxy
	if [ "6" == "$ss_dns_foreign"  ]; then
			echo_date 开启Pcap_DNSProxy..
			#sed -i "/^Listen Port/c Listen Port = $DNS_PORT" $KSROOT/ss/dns/Config.ini
			Pcap_DNSProxy -c /koolshare/ss/dns
	fi
}
#--------------------------------------------------------------------------------------

create_dnsmasq_conf(){
	# append china site
	rm -rf /tmp/sscdn.conf
	if [ "$ss_dns_plan" == "2" ] && [ "$ss_dns_foreign" != "5" ] && [ "$ss_dns_foreign" != "6" ];then
		echo_date 生成cdn加速列表到/tmp/sscdn.conf，加速用的dns：$CDN
		echo "#for china site CDN acclerate" >> /tmp/sscdn.conf
		cat $KSROOT/ss/rules/cdn.txt | sed "s/^/server=&\/./g" | sed "s/$/\/&$CDN/g" | sort | awk '{if ($0!=line) print;line=$0}' >>/tmp/sscdn.conf
	fi

	# append user defined china site
	if [ -n "$ss_isp_website_web" ];then
		cdnsites=$(echo $ss_isp_website_web | base64_decode)
		echo_date 生成自定义cdn加速域名到/tmp/sscdn.conf
		echo "#for user defined china site CDN acclerate" >> /tmp/sscdn.conf
		for cdnsite in $cdnsites
		do
			echo "$cdnsite" | sed "s/^/server=&\/./g" | sed "s/$/\/&$CDN/g" >> /tmp/sscdn.conf
		done
	fi
	
	rm -rf /tmp/custom.conf
	if [ -n "$ss_dnsmasq" ];then
		echo_date 添加自定义dnsmasq设置到/tmp/custom.conf
		echo "$ss_dnsmasq" | base64_decode | sort -u >> /tmp/custom.conf
	fi

	# append white domain list, bypass ss
	rm -rf /tmp/wblist.conf
	# github need to go ss
	echo "#for router itself" >> /tmp/wblist.conf
	echo "server=/.google.com.tw/127.0.0.1#7913" >> /tmp/wblist.conf
	echo "ipset=/.google.com.tw/router" >> /tmp/wblist.conf
	echo "server=/.github.com/127.0.0.1#7913" >> /tmp/wblist.conf
	echo "ipset=/.github.com/router" >> /tmp/wblist.conf
	echo "server=/.github.io/127.0.0.1#7913" >> /tmp/wblist.conf
	echo "ipset=/.github.io/router" >> /tmp/wblist.conf
	echo "server=/.raw.githubusercontent.com/127.0.0.1#7913" >> /tmp/wblist.conf
	echo "ipset=/.raw.githubusercontent.com/router" >> /tmp/wblist.conf
	echo "server=/.apnic.net/127.0.0.1#7913" >> /tmp/wblist.conf
	echo "ipset=/.apnic.net/router" >> /tmp/wblist.conf
	# append white domain list,not through ss
	wanwhitedomain=$(echo $ss_wan_white_domain | base64_decode)
	if [ -n "$ss_wan_white_domain" ];then
		echo_date 应用域名白名单
		echo "#for white_domain" >> //tmp/wblist.conf
		for wan_white_domain in $wanwhitedomain
		do 
			echo "$wan_white_domain" | sed "s/^/server=&\/./g" | sed "s/$/\/127.0.0.1#7913/g" >> /tmp/wblist.conf
			echo "$wan_white_domain" | sed "s/^/ipset=&\/./g" | sed "s/$/\/white_list/g" >> /tmp/wblist.conf
		done
	fi
	# apple 和microsoft不能走ss
	echo "#for special site" >> //tmp/wblist.conf
	for wan_white_domain2 in "apple.com" "microsoft.com"
	do 
		echo "$wan_white_domain2" | sed "s/^/server=&\/./g" | sed "s/$/\/$CDN#53/g" >> /tmp/wblist.conf
		echo "$wan_white_domain2" | sed "s/^/ipset=&\/./g" | sed "s/$/\/white_list/g" >> /tmp/wblist.conf
	done
	
	# append black domain list,through ss
	wanblackdomain=$(echo $ss_wan_black_domain | base64_decode)
	if [ -n "$ss_wan_black_domain" ];then
		echo_date 应用域名黑名单
		echo "#for black_domain" >> /tmp/wblist.conf
		for wan_black_domain in $wanblackdomain
		do 
			echo "$wan_black_domain" | sed "s/^/server=&\/./g" | sed "s/$/\/127.0.0.1#7913/g" >> /tmp/wblist.conf
			echo "$wan_black_domain" | sed "s/^/ipset=&\/./g" | sed "s/$/\/black_list/g" >> /tmp/wblist.conf
		done
	fi
	# ln conf
	# custom dnsmasq
	rm -rf /tmp/dnsmasq.d/custom.conf
	if [ -f /tmp/custom.conf ];then
		echo_date 创建域自定义dnsmasq配置文件软链接到/tmp/dnsmasq.d/custom.conf
		mv /tmp/custom.conf /tmp/dnsmasq.d/custom.conf
	fi
	# custom dnsmasq
	rm -rf /tmp/dnsmasq.d/wblist.conf
	if [ -f /tmp/wblist.conf ];then
		echo_date 创建域名黑/白名单软链接到/tmp/dnsmasq.d/wblist.conf
		mv /tmp/wblist.conf /tmp/dnsmasq.d/wblist.conf
	fi
	rm -rf /tmp/dnsmasq.d/cdn.conf
	if [ -f /tmp/sscdn.conf ];then
		echo_date 创建cdn加速列表软链接/tmp/dnsmasq.d/cdn.conf
		mv /tmp/sscdn.conf /tmp/dnsmasq.d/cdn.conf
	fi
	gfw_on=`dbus list ss_acl_mode|cut -d "=" -f 2 | grep 1`	
	rm -rf /tmp/dnsmasq.d/gfwlist.conf
	if [ "$ss_basic_mode" == "1" ];then
		echo_date 创建gfwlist的软连接到/tmp/dnsmasq.d/文件夹.
		ln -sf $KSROOT/ss/rules/gfwlist.conf /tmp/dnsmasq.d/gfwlist.conf
	elif [ "$ss_basic_mode" == "2" ] || [ "$ss_basic_mode" == "3" ];then
		if [ ! -f /tmp/dnsmasq.d/gfwlist.conf ] && [ "$ss_dns_plan" == "1" ] || [ -n "$gfw_on" ];then
			echo_date 创建gfwlist的软连接到/tmp/dnsmasq.d/文件夹.
			ln -sf $KSROOT/ss/rules/gfwlist.conf /tmp/dnsmasq.d/gfwlist.conf
		fi
	fi
	
	if [ "$ss_dns_china" == "1" ];then
		IFIP_DNS1=`echo $ISP_DNS1|grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:"`
		IFIP_DNS2=`echo $ISP_DNS2|grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}|:"`
		[ -n "$IFIP_DNS1" ] && CDN1="$ISP_DNS1" || CDN1="114.114.114.114"
		[ -n "$IFIP_DNS2" ] && CDN2="$ISP_DNS2" || CDN2="114.114.115.115"
	fi
	[ "$ss_dns_china" == "2" ] && CDN="223.5.5.5"
	[ "$ss_dns_china" == "3" ] && CDN="223.6.6.6"
	[ "$ss_dns_china" == "4" ] && CDN="114.114.114.114"
	[ "$ss_dns_china" == "5" ] && CDN="114.114.115.115"
	[ "$ss_dns_china" == "6" ] && CDN="1.2.4.8"
	[ "$ss_dns_china" == "7" ] && CDN="210.2.4.8"
	[ "$ss_dns_china" == "8" ] && CDN="112.124.47.27"
	[ "$ss_dns_china" == "9" ] && CDN="114.215.126.16"
	[ "$ss_dns_china" == "10" ] && CDN="180.76.76.76"
	[ "$ss_dns_china" == "11" ] && CDN="119.29.29.29"
	[ "$ss_dns_china" == "12" ] && CDN="$ss_dns_china_user"
	
	echo "no-resolv" >> /tmp/dnsmasq.d/ssserver.conf
	if [ "$ss_dns_plan" == "1" ] || [ -z "$ss_dns_china" ];then
		if [ "$ss_dns_china" == "1" ];then
			echo_date DNS解析方案国内优先，使用运营商DNS优先解析国内DNS.
			echo "all-servers" >> /tmp/dnsmasq.d/ssserver.conf
			echo "server=$CDN1#53" >> /tmp/dnsmasq.d/ssserver.conf
			echo "server=$CDN2#53" >> /tmp/dnsmasq.d/ssserver.conf
		else
			echo_date DNS解析方案国内优先，使用自定义DNS：$CDN进行解析国内DNS.
			echo "server=$CDN#53" >> /tmp/dnsmasq.d/ssserver.conf
		fi
	elif [ "$ss_dns_plan" == "2" ];then
		echo_date DNS解析方案国外优先，优先解析国外DNS.
		echo "server=127.0.0.1#7913" >> /tmp/dnsmasq.d/ssserver.conf
	fi
}

#--------------------------------------------------------------------------------------
auto_start(){
	# nat start
	echo_date 添加nat-start触发事件...
	uci -q batch <<-EOT
	  delete firewall.ks_shadowsocks
	  set firewall.ks_shadowsocks=include
	  set firewall.ks_shadowsocks.type=script
	  set firewall.ks_shadowsocks.path=/koolshare/ss/ssstart.sh
	  set firewall.ks_shadowsocks.family=any
	  set firewall.ks_shadowsocks.reload=1
	  commit firewall
	EOT

	# auto start
	echo_date 加入开机自动启动...
	[ ! -L "/etc/rc.d/S99shadowsocks.sh" ] && ln -sf $KSROOT/init.d/S99shadowsocks.sh /etc/rc.d/S99shadowsocks.sh

	# cron job
	if [ "1" == "$ss_basic_rule_update" ]; then
		echo_date 添加ss规则定时更新任务，每天"$ss_basic_rule_update_time"自动检测更新规则.
		# cru a ssupdate "0 $ss_basic_rule_update_time * * * /bin/sh $KSROOT/scripts/ss_rule_update.sh"
		echo "0 $ss_basic_rule_update_time * * * /bin/sh $KSROOT/scripts/ss_rule_update.sh #ssupdate#" >>/etc/crontabs/root
	else
		echo_date ss规则定时更新任务未启用！
	fi
}

#=======================================================================================
start_ss_redir(){
	# Start ss-redir
	if [ "$ss_basic_type" == "1" ];then
		echo_date 开启ssr-redir进程，用于透明代理.
		ssr-redir -b 0.0.0.0 -c $CONFIG_FILE -u -f /var/run/shadowsocks.pid >/dev/null 2>&1
	elif  [ "$ss_basic_type" == "0" ];then
		echo_date 开启ss-redir进程，用于透明代理.
		if [ "$ss_basic_ss_obfs" == "0" ];then
			ss-redir -b 0.0.0.0 -c $CONFIG_FILE -u -f /var/run/shadowsocks.pid >/dev/null 2>&1
		else
			ss-redir -b 0.0.0.0 -c $CONFIG_FILE -u --plugin obfs-local --plugin-opts "$ARG_OBFS" -f /var/run/shadowsocks.pid >/dev/null 2>&1
		fi
	fi
}

# =======================================================================================================
flush_nat(){
	echo_date 尝试先清除已存在的iptables规则，防止重复添加
	# flush rules and set if any
	iptables -t nat -D PREROUTING -p tcp -j SHADOWSOCKS >/dev/null 2>&1
	sleep 1
	iptables -t nat -F SHADOWSOCKS > /dev/null 2>&1 && iptables -t nat -X SHADOWSOCKS > /dev/null 2>&1
	iptables -t nat -F SHADOWSOCKS_EXT > /dev/null 2>&1
	iptables -t nat -F SHADOWSOCKS_GFW > /dev/null 2>&1 && iptables -t nat -X SHADOWSOCKS_GFW > /dev/null 2>&1
	iptables -t nat -F SHADOWSOCKS_CHN > /dev/null 2>&1 && iptables -t nat -X SHADOWSOCKS_CHN > /dev/null 2>&1
	iptables -t nat -F SHADOWSOCKS_GAM > /dev/null 2>&1 && iptables -t nat -X SHADOWSOCKS_GAM > /dev/null 2>&1
	iptables -t nat -F SHADOWSOCKS_GLO > /dev/null 2>&1 && iptables -t nat -X SHADOWSOCKS_GLO > /dev/null 2>&1
	iptables -t mangle -D PREROUTING -p udp -j SHADOWSOCKS >/dev/null 2>&1
	iptables -t mangle -F SHADOWSOCKS >/dev/null 2>&1 && iptables -t mangle -X SHADOWSOCKS >/dev/null 2>&1
	iptables -t mangle -F SHADOWSOCKS_GAM > /dev/null 2>&1 && iptables -t mangle -X SHADOWSOCKS_GAM > /dev/null 2>&1
	iptables -t nat -D OUTPUT -p tcp -m set --match-set router dst -j REDIRECT --to-ports 3333 >/dev/null 2>&1
	iptables -t nat -F OUTPUT > /dev/null 2>&1
	iptables -t nat -X SHADOWSOCKS_EXT > /dev/null 2>&1
	
	kp_mode=`/koolshare/bin/dbus get koolproxy_mode`
	kp_enable=`iptables -t nat -L PREROUTING | grep KOOLPROXY |wc -l`
	chromecast_nu=`iptables -t nat -L PREROUTING -v -n --line-numbers|grep "dpt:53"|awk '{print $1}'`
	if [ "$kp_mode" != "2" ] || [ "$kp_enable" -eq 0 ]; then
		iptables -t nat -D PREROUTING $chromecast_nu >/dev/null 2>&1
	fi

	#flush_ipset
	echo_date 先清空已存在的ipset名单，防止重复添加
	ipset -F chnroute >/dev/null 2>&1 && ipset -X chnroute >/dev/null 2>&1
	ipset -F white_list >/dev/null 2>&1 && ipset -X white_list >/dev/null 2>&1
	ipset -F black_list >/dev/null 2>&1 && ipset -X black_list >/dev/null 2>&1
	ipset -F gfwlist >/dev/null 2>&1 && ipset -X gfwlist >/dev/null 2>&1
	ipset -F router >/dev/null 2>&1 && ipset -X router >/dev/null 2>&1

	#remove_redundant_rule
	ip_rule_exist=`/usr/sbin/ip rule show | grep "fwmark 0x1/0x1 lookup 310" | grep -c 310`
	if [ ! -z "ip_rule_exist" ];then
		echo_date 清除重复的ip rule规则.
		until [ "$ip_rule_exist" = 0 ]
		do 
			#ip rule del fwmark 0x07 table 310
			/usr/sbin/ip rule del fwmark 0x07 table 310 pref 789
			ip_rule_exist=`expr $ip_rule_exist - 1`
		done
	fi

	# remove_route_table
	echo_date 删除ip route规则.
	/usr/sbin/ip route del local 0.0.0.0/0 dev lo table 310 >/dev/null 2>&1
}

# creat ipset rules
creat_ipset(){
	echo_date 创建ipset名单
	ipset -! create white_list nethash && ipset flush white_list
	ipset -! create black_list nethash && ipset flush black_list
	ipset -! create gfwlist nethash && ipset flush gfwlist
	ipset -! create router nethash && ipset flush router
	ipset -! create chnroute nethash && ipset flush chnroute
	sed -e "s/^/add chnroute &/g" $KSROOT/ss/rules/chnroute.txt | awk '{print $0} END{print "COMMIT"}' | ipset -R
}

add_white_black_ip(){
	# black ip/cidr
	ip_tg="149.154.0.0/16 91.108.4.0/22 91.108.56.0/24 109.239.140.0/24 67.198.55.0/24"
	for ip in $ip_tg
	do
		ipset -! add black_list $ip >/dev/null 2>&1
	done
	
	if [ ! -z $ss_wan_black_ip ];then
		ss_wan_black_ip=`dbus get ss_wan_black_ip|base64_decode|sed '/\#/d'`
		echo_date 应用IP/CIDR黑名单
		for ip in $ss_wan_black_ip
		do
			ipset -! add black_list $ip >/dev/null 2>&1
		done
	fi
	
	# white ip/cidr
	#ip1=$(nvram get wan0_ipaddr | cut -d"." -f1,2)
	ip1=`cat /etc/config/pppoe|grep localip | awk '{print $4}'| cut -d"." -f1,2`
	[ ! -z "$ss_basic_server_ip" ] && SERVER_IP=$ss_basic_server_ip || SERVER_IP=""
	ip_lan="0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4 $ip1.0.0/16 $SERVER_IP 223.5.5.5 223.6.6.6 114.114.114.114 114.114.115.115 1.2.4.8 210.2.4.8 112.124.47.27 114.215.126.16 180.76.76.76 119.29.29.29 $ISP_DNS1 $ISP_DNS2"
	for ip in $ip_lan
	do
		ipset -! add white_list $ip >/dev/null 2>&1
	done
	
	if [ ! -z $ss_wan_white_ip ];then
		ss_wan_white_ip=`echo $ss_wan_white_ip|base64_decode|sed '/\#/d'`
		echo_date 应用IP/CIDR白名单
		for ip in $ss_wan_white_ip
		do
			ipset -! add white_list $ip >/dev/null 2>&1
		done
	fi
}

get_action_chain() {
	case "$1" in
		0)
			echo "RETURN"
		;;
		1)
			echo "SHADOWSOCKS_GFW"
		;;
		2)
			echo "SHADOWSOCKS_CHN"
		;;
		3)
			echo "SHADOWSOCKS_GAM"
		;;
		4)
			echo "SHADOWSOCKS_GLO"
		;;
	esac
}

get_mode_name() {
	case "$1" in
		0)
			echo "不通过SS"
		;;
		1)
			echo "gfwlist模式"
		;;
		2)
			echo "大陆白名单模式"
		;;
		3)
			echo "游戏模式"
		;;
		4)
			echo "全局模式"
		;;
	esac
}

factor(){
	if [ -z "$1" ] || [ -z "$2" ]; then
		echo ""
	else
		echo "$2 $1"
	fi
}

get_jump_mode(){
	case "$1" in
		0)
			echo "j"
		;;
		*)
			echo "g"
		;;
	esac
}

lan_acess_control(){
	# lan access control
	acl_nu=`dbus list ss_acl_mode|sort -n -t "=" -k 2|cut -d "=" -f 1 | cut -d "_" -f 4`
	if [ -n "$acl_nu" ]; then
		for acl in $acl_nu
		do
			ipaddr=`dbus get ss_acl_ip_$acl`
			ipaddr_hex=`dbus get ss_acl_ip_$acl | awk -F "." '{printf ("0x%02x", $1)} {printf ("%02x", $2)} {printf ("%02x", $3)} {printf ("%02x\n", $4)}'`
			ports=`dbus get ss_acl_port_$acl`
			[ "$ports" == "all" ] && ports=""
			proxy_mode=`dbus get ss_acl_mode_$acl`
			proxy_name=`dbus get ss_acl_name_$acl`
			mac=`dbus get ss_acl_mac_$acl`

			#[ "$ports" == "" ] && echo_date 加载ACL规则：【$ipaddr】【$mac】:all模式为：$(get_mode_name $proxy_mode) || echo_date 加载ACL规则：【$ipaddr】【$mac】:$ports模式为：$(get_mode_name $proxy_mode)
			if [ "$ports" == "" ];then
				[ -n "$ipaddr" ] && [ -z "$mac" ] && echo_date 加载ACL规则：【$ipaddr】:all模式为：$(get_mode_name $proxy_mode)
				[ -z "$ipaddr" ] && [ -n "$mac" ] && echo_date 加载ACL规则：【$mac】:all模式为：$(get_mode_name $proxy_mode)
				[ -n "$ipaddr" ] && [ -n "$mac" ] && echo_date 加载ACL规则：【$ipaddr】【$mac】:all模式为：$(get_mode_name $proxy_mode)
			else
				[ -n "$ipaddr" ] && [ -z "$mac" ] && echo_date 加载ACL规则：【$ipaddr】:$ports模式为：$(get_mode_name $proxy_mode)
				[ -z "$ipaddr" ] && [ -n "$mac" ] && echo_date 加载ACL规则：【$mac】:$ports模式为：$(get_mode_name $proxy_mode)
				[ -n "$ipaddr" ] && [ -n "$mac" ] && echo_date 加载ACL规则：【$ipaddr】【$mac】:$ports模式为：$(get_mode_name $proxy_mode)
			fi
			# acl in SHADOWSOCKS for nat
			iptables -t nat -A SHADOWSOCKS $(factor $ipaddr "-s") $(factor $mac "-m mac --mac-source") -p tcp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
			# acl in SHADOWSOCKS for mangle
			if [ "$proxy_mode" == "3" ];then
				iptables -t mangle -A SHADOWSOCKS $(factor $ipaddr "-s") $(factor $mac "-m mac --mac-source") -p udp $(factor $ports "-m multiport --dport") -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)
			else
				iptables -t mangle -A SHADOWSOCKS $(factor $ipaddr "-s") $(factor $mac "-m mac --mac-source") -p udp -j RETURN
			fi
			# acl in OUTPUT（used by koolproxy）
			[ -z "$ipaddr" ] && {
				lower_macaddr=`echo $mac | tr '[A-Z]' '[a-z]'`
				ipaddr=`ip neigh show | grep $lower_macaddr | awk '{print $1}'`
				[ -z "$ipaddr" ] && ipaddr=`cat /tmp/dhcp.leases |grep $lower_macaddr |awk '{print $3}'`
				[ -z "$ipaddr" ] && {
					dhcp_index=`uci show dhcp | grep $lower_macaddr |awk -F'.' '{print $2}'`
					ipaddr=`uci -q get dhcp.$dhcp_index.ip`
				}	
				[ -n "$ipaddr" ] && ipaddr_hex=`echo -n $ipaddr | awk -F "." '{printf ("0x%02x", $1)} {printf ("%02x", $2)} {printf ("%02x", $3)} {printf ("%02x\n", $4)}'`
			}
			iptables -t nat -A SHADOWSOCKS_EXT -p tcp  $(factor $ports "-m multiport --dport") -m mark --mark "$ipaddr_hex" -$(get_jump_mode $proxy_mode) $(get_action_chain $proxy_mode)

		done
		echo_date 加载ACL规则：其余主机模式为：$(get_mode_name $ss_acl_default_mode)
	else
		ss_acl_default_mode="$ss_basic_mode"
		echo_date 加载ACL规则：所有模式为：$(get_mode_name $ss_basic_mode)
	fi
}

apply_nat_rules(){
	#----------------------BASIC RULES---------------------
	echo_date 写入iptables规则到nat表中...
	# 创建SHADOWSOCKS nat rule
	iptables -t nat -N SHADOWSOCKS
	# 扩展
	iptables -t nat -N SHADOWSOCKS_EXT
	# IP/cidr/白域名 白名单控制（不走ss） for SHADOWSOCKS
	iptables -t nat -A SHADOWSOCKS -p tcp -m set --match-set white_list dst -j RETURN
	# IP/cidr/白域名 白名单控制（不走ss） for SHADOWSOCKS_EXT
	iptables -t nat -A SHADOWSOCKS_EXT -p tcp -m set --match-set white_list dst -j RETURN
	#-----------------------FOR GLOABLE---------------------
	# 创建gfwlist模式nat rule
	iptables -t nat -N SHADOWSOCKS_GLO
	# IP黑名单控制-gfwlist（走ss）
	iptables -t nat -A SHADOWSOCKS_GLO -p tcp -j REDIRECT --to-ports 3333
	#-----------------------FOR GFWLIST---------------------
	# 创建gfwlist模式nat rule
	iptables -t nat -N SHADOWSOCKS_GFW
	# IP/CIDR/黑域名 黑名单控制（走ss）
	iptables -t nat -A SHADOWSOCKS_GFW -p tcp -m set --match-set black_list dst -j REDIRECT --to-ports 3333
	# IP黑名单控制-gfwlist（走ss）
	iptables -t nat -A SHADOWSOCKS_GFW -p tcp -m set --match-set gfwlist dst -j REDIRECT --to-ports 3333
	#-----------------------FOR CHNMODE---------------------
	# 创建大陆白名单模式nat rule
	iptables -t nat -N SHADOWSOCKS_CHN
	# IP/CIDR/域名 黑名单控制（走ss）
	iptables -t nat -A SHADOWSOCKS_CHN -p tcp -m set --match-set black_list dst -j REDIRECT --to-ports 3333
	# cidr黑名单控制-chnroute（走ss）
	iptables -t nat -A SHADOWSOCKS_CHN -p tcp -m set ! --match-set chnroute dst -j REDIRECT --to-ports 3333
	#-----------------------FOR GAMEMODE---------------------
	# 创建大陆白名单模式nat rule
	iptables -t nat -N SHADOWSOCKS_GAM
	# IP/CIDR/域名 黑名单控制（走ss）
	iptables -t nat -A SHADOWSOCKS_GAM -p tcp -m set --match-set black_list dst -j REDIRECT --to-ports 3333
	# cidr黑名单控制-chnroute（走ss）
	iptables -t nat -A SHADOWSOCKS_GAM -p tcp -m set ! --match-set chnroute dst -j REDIRECT --to-ports 3333

	#[ "$mangle" == "1" ] && load_tproxy
	[ "$mangle" == "1" ] && /usr/sbin/ip rule add fwmark 0x07 table 310 pref 789
	[ "$mangle" == "1" ] && /usr/sbin/ip route add local 0.0.0.0/0 dev lo table 310
	# 创建游戏模式udp rule
	[ "$mangle" == "1" ] && iptables -t mangle -N SHADOWSOCKS
	# IP/cidr/白域名 白名单控制（不走ss）
	[ "$mangle" == "1" ] && iptables -t mangle -A SHADOWSOCKS -p udp -m set --match-set white_list dst -j RETURN
	# 创建游戏模式udp rule
	[ "$mangle" == "1" ] && iptables -t mangle -N SHADOWSOCKS_GAM
	# IP/CIDR/域名 黑名单控制（走ss）
	[ "$mangle" == "1" ] && iptables -t mangle -A SHADOWSOCKS_GAM -p udp -m set --match-set black_list dst -j TPROXY --on-port 3333 --tproxy-mark 0x07
	# cidr黑名单控制-chnroute（走ss）
	[ "$mangle" == "1" ] && iptables -t mangle -A SHADOWSOCKS_GAM -p udp -m set ! --match-set chnroute dst -j TPROXY --on-port 3333 --tproxy-mark 0x07
	#-------------------------------------------------------
	# 局域网黑名单（不走ss）/局域网黑名单（走ss）
	lan_acess_control
	#-----------------------FOR ROUTER---------------------
	# router itself
	iptables -t nat -A OUTPUT -p tcp -m set --match-set router dst -j REDIRECT --to-ports 3333
	[ "$ss_basic_mode" != "4" ] && iptables -t nat -A OUTPUT -p tcp -m mark --mark $ip_prefix_hex -j SHADOWSOCKS_EXT
	#[ "$ss_basic_mode" != "4" ] && iptables -t nat -A OUTPUT -p tcp -m ttl --ttl-eq 160 -j SHADOWSOCKS_EXT
	
	# 把最后剩余流量重定向到相应模式的nat表中对对应的主模式的链
	[ "$ss_acl_default_port" == "all" ] && ss_acl_default_port=""
	iptables -t nat -A SHADOWSOCKS -p tcp $(factor $ss_acl_default_port "-m multiport --dport") -j $(get_action_chain $ss_acl_default_mode)
	# iptables -t nat -A OUTPUT -p tcp $(factor $ss_acl_default_port "-m multiport --dport") -m ttl --ttl-eq 160 -j $(get_action_chain $ss_acl_default_mode)
	iptables -t nat -A SHADOWSOCKS_EXT -p tcp $(factor $ss_acl_default_port "-m multiport --dport") -j $(get_action_chain $ss_acl_default_mode)
	# 如果是主模式游戏模式，则把SHADOWSOCKS链中剩余udp流量转发给SHADOWSOCKS_GAM链
	# 如果主模式不是游戏模式，则不需要把SHADOWSOCKS链中剩余udp流量转发给SHADOWSOCKS_GAM，不然会造成其他模式主机的udp也走游戏模式
	[ "$mangle" == "1" ] && ss_acl_default_mode=3
	[ "$ss_basic_mode" == "3" ] && iptables -t mangle -A SHADOWSOCKS -p udp -j $(get_action_chain $ss_acl_default_mode)
	# 重定所有流量到 SHADOWSOCKS
	KP_INDEX=`iptables -t nat -L PREROUTING|tail -n +3|sed -n -e '/^KOOLPROXY/='`
	if [ -n "$KP_INDEX" ]; then
		let KP_INDEX+=1
		#确保添加到KOOLPROXY规则之后
		iptables -t nat -I PREROUTING $KP_INDEX -p tcp -j SHADOWSOCKS
	else
		PR_INDEX=`iptables -t nat -L PREROUTING|tail -n +3|sed -n -e '/^prerouting_rule/='`|| 1
		#如果kp没有运行，确保添加到prerouting_rule规则之后
		let PR_INDEX+=1	
		iptables -t nat -I PREROUTING $PR_INDEX -p tcp -j SHADOWSOCKS
	fi
	[ "$mangle" == "1" ] && iptables -t mangle -I PREROUTING 1 -p udp -j SHADOWSOCKS
}

chromecast(){
	LOG1=开启chromecast功能（DNS劫持功能）
	LOG2=chromecast功能未开启，建议开启~
	kp_mode=`/koolshare/bin/dbus get koolproxy_mode`
	kp_enable=`iptables -t nat -L PREROUTING | grep KOOLPROXY |wc -l`
	chromecast_nu=`iptables -t nat -L PREROUTING -v -n --line-numbers|grep "dpt:53"|awk '{print $1}'`
	is_right_lanip=`iptables -t nat -L PREROUTING -v -n --line-numbers|grep "dpt:53" |grep "$lan_ipaddr"`
	if [ "$ss_basic_chromecast" == "1" ];then
		uci set shadowsocks.@global[0].dns_53=1
		if [ -z "$chromecast_nu" ]; then
			iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to $lan_ipaddr >/dev/null 2>&1
			echo_date $LOG1
		else
			if [ -z "$is_right_lanip" ]; then
				echo_date 黑名单模式开启DNS劫持
				iptables -t nat -D PREROUTING $chromecast_nu >/dev/null 2>&1
				iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to $lan_ipaddr >/dev/null 2>&1
			else
				echo_date DNS劫持规则已经添加，跳过~
			fi
		fi
	else
		uci set shadowsocks.@global[0].dns_53=0
		if [ "$kp_mode" != "2" ] || [ "$kp_enable" -eq 0 ]; then
			iptables -t nat -D PREROUTING $chromecast_nu >/dev/null 2>&1
			echo_date $LOG2
		fi
	fi
	uci commit
}
# =======================================================================================================
#---------------------------------------------------------------------------------------------------------
load_nat(){
	echo_date "加载nat规则!"
	flush_nat
	creat_ipset
	add_white_black_ip
	apply_nat_rules
	chromecast
}

restart_dnsmasq(){
	# Restart dnsmasq
	echo_date 重启dnsmasq服务...
	/etc/init.d/dnsmasq restart >/dev/null 2>&1
}

write_numbers(){
	dbus set ss_basic_version=`cat /koolshare/ss/version`
	
	ipset_numbers=`cat $KSROOT/ss/rules/gfwlist.conf | grep -c ipset`
	chnroute_numbers=`cat $KSROOT/ss/rules/chnroute.txt | grep -c .`
	cdn_numbers=`cat $KSROOT/ss/rules/cdn.txt | grep -c .`
	update_ipset=`cat $KSROOT/ss/rules/version | sed -n 1p | sed 's/#/\n/g'| sed -n 1p`
	update_chnroute=`cat $KSROOT/ss/rules/version | sed -n 2p | sed 's/#/\n/g'| sed -n 1p`
	update_cdn=`cat $KSROOT/ss/rules/version | sed -n 4p | sed 's/#/\n/g'| sed -n 1p`
	dbus set ss_gfw_status="$ipset_numbers 条，最后更新版本： $update_ipset "
	dbus set ss_chn_status="$chnroute_numbers 条，最后更新版本： $update_chnroute "
	dbus set ss_cdn_status="$cdn_numbers 条，最后更新版本： $update_cdn "
}

# for debug
get_status(){
	echo =========================================================
	echo `date` 123
	echo "PID of this script: $$"
	echo "PPID of this script: $PPID"
	echo ------------------------------------
	ps -l|grep $$|grep -v grep
	echo ------------------------------------
	ps -l|grep $PPID|grep -v grep
	echo ------------------------------------
	
	iptables -nvL PREROUTING -t nat
	#iptables -nvL SHADOWSOCKS -t nat
	#iptables -nvL SHADOWSOCKS_EXT -t nat
	#iptables -nvL SHADOWSOCKS_GFW -t nat
	#iptables -nvL SHADOWSOCKS_CHN -t nat
	#iptables -nvL SHADOWSOCKS_GAM -t nat
	#iptables -nvL SHADOWSOCKS_GLO -t nat
}

# router is on boot
ONSTART=`ps -l|grep $PPID|grep -v grep|grep S99shadowsocks`

case $1 in
restart)
	# used by web for start/restart; or by system for startup by S99shadowsocks.sh in rc.d
	while [ -f "$LOCK_FILE" ]; do
		sleep 1
	done
	echo_date ---------------------- LEDE 固件 shadowsocks -----------------------
	# stop first
	restore_dnsmasq_conf
	if [ -z "$IFIP" ] && [ -z "$ONSTART" ];then
		restart_dnsmasq
	else
		[ "$ss_basic_node" == "0" ] && [ -n "$ss_lb_node_max" ] && restart_dnsmasq
	fi
	flush_nat
	restore_start_file
	kill_process
	kill_cron_job
	echo_date ---------------------------------------------------------------------------------------
	[ -f "$LOCK_FILE" ] && return 1
	touch "$LOCK_FILE"
	# start
	resolv_server_ip
	[ -z "$ONSTART" ] && creat_ss_json
	create_dnsmasq_conf
	auto_start
	start_ss_redir
	load_nat
	[ "$ss_basic_node" == "0" ] && [ -n "$ss_lb_node_max" ] && start_haproxy
	restart_dnsmasq
	start_dns
	write_numbers
	echo_date ------------------------- shadowsocks 启动完毕 -------------------------
	# get_status >> /tmp/ss_start.txt
	# do not start by nat when start up
	[ ! -f "/tmp/shadowsocks.nat_lock" ] && touch /tmp/shadowsocks.nat_lock
	rm -f "$LOCK_FILE"
	return 0
	;;
stop)
	#only used by web stop
	while [ -f "$LOCK_FILE" ]; do
		sleep 1
	done
	echo_date ---------------------- LEDE 固件 shadowsocks -----------------------
	restore_dnsmasq_conf
	restart_dnsmasq
	flush_nat
	restore_start_file
	kill_process
	kill_cron_job
	echo_date ------------------------- shadowsocks 成功关闭 -------------------------
	;;
lb_restart)
	[ -n "`pidof haproxy`" ] && echo_date 关闭haproxy进程... && killall haproxy
	[ "$ss_basic_node" == "0" ] && [ -n "$ss_lb_node_max" ] && start_haproxy
	;;
*)
	# for nat
	[ ! -f "/tmp/shadowsocks.nat_lock" ] && exit 0
	while [ -f "$LOCK_FILE" ]; do
		sleep 1
	done
	restore_dnsmasq_conf
	[ "$ss_basic_node" == "0" ] && [ -n "$ss_lb_node_max" ] && restart_dnsmasq
	kill_process
	load_nat
	start_ss_redir
	[ "$ss_basic_node" == "0" ] && [ -n "$ss_lb_node_max" ] && start_haproxy
	start_dns
	create_dnsmasq_conf
	restart_dnsmasq
	;;
esac
