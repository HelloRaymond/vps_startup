VPS 初始化配置脚本
===========

VPS基础环境的配置

安装
------

- 用法

	- Debian / Ubuntu:
	```bash
		sudo apt-get install git && git clone https://github.com/HelloRaymond/vps_startup.git
		cd vps_startup.git && sudo bash ./startup.sh
	```
	CentOS:
	```bash
		yum install git && git clone https://github.com/HelloRaymond/vps_startup.git 
		cd vps_startup.git && bash ./startup.sh
	```

简介
-------------
- 安装 Docker-CE 和一些其他的配置工具
- 配置 SSH
	- 更改SSH端口为 8022 并且配置密钥登录
	- 如果您已经拥有了一个公钥文件, 请把它放在该脚本文件相同的目录下，并重命名为authorized_keys.pub. 否则, 将会自动生成一个密钥对。
	- Note:
		- 如果您自己提供了一个公钥文件，SSH密码登录将会被禁用
		- 否则，您需要手动键入以下命令来禁用密码登录
        `sed 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config`
- 配置防火墙
	- 只允许以下端口: 80 443 8888 888 8022
- 配置网络加速
	- 只有当前内核版本大于4.9时才会自动配置bbr加速


