REMOTE_HOSTS := t220 xjwq0 wyp
dns: genwgset.sh
	@./genwgset.sh
	@for host in $(REMOTE_HOSTS); do \
		echo "正在复制到 $$host..."; \
		scp -O nfset.conf $$host:/etc/dnsmasq.d/; \
		if [ $$? -ne 0 ]; then \
			echo "错误：复制到 $$host 失败！"; \
		fi; \
		ssh $$host 'service dnsmasq restart'; \
	done
rr: genwgset.sh
	sed 's/\/8.8.8.8/\/192.168.111.1/g' nfset.conf > /tmp/nfset.conf
	scp -O /tmp/nfset.conf redmi:/etc/dnsmasq.d/
	ssh redmi 'service dnsmasq restart'
	scp -O /tmp/nfset.conf xjwq0:/etc/dnsmasq.d/
	ssh xjwq0 'service dnsmasq restart'
