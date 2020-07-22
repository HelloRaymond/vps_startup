#!/bin/bash
printColor()
{
    RED_COLOR='\E[1;31m' #红
    GREEN_COLOR='\E[1;32m' #绿
    YELOW_COLOR='\E[1;33m' #黄
    BLUE_COLOR='\E[1;34m' #蓝
    PINK_COLOR='\E[1;35m' #粉
    RES='\E[0m'
    case $1 in
        'red')
            echo -e  "${RED_COLOR}${2}${RES}"
            ;;
        'green')
            echo -e  "${GREEN_COLOR}${2}${RES}"
            ;;
        'yellow')
            echo -e  "${YELOW_COLOR}${2}${RES}"
            ;;
        'blue')
            echo -e  "${BLUE_COLOR}${2}${RES}"
            ;;
        'pink')
            echo -e  "${PINK_COLOR}${2}${RES}"
            ;;
        *)
            echo $1
    esac
}

checkUser()
{
    if [ $UID -ne 0 ]; then
        printColor red '此脚本需要以管理员权限运行' >> /dev/stderr
        printColor yellow "例如：\"$0\""
        exit 1
    fi
}

#获取操作系统相关信息
#全局变量 Distro PackageManager OS_Ver Kernel_Ver
getSystemInfo()
{
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        Distro='CentOS'
        PackageManager='yum'
    elif grep -Eqi "Red Hat Enterprise Linux Server" /etc/issue || grep -Eq "Red Hat Enterprise Linux Server" /etc/*-release; then
        Distro='RHEL'
        PackageManager='yum'
    elif grep -Eqi "Aliyun" /etc/issue || grep -Eq "Aliyun" /etc/*-release; then
        Distro='Aliyun'
        PackageManager='yum'
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        Distro='Fedora'
        PackageManager='yum'
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        Distro='Debian'
        PackageManager='apt'
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        Distro='Ubuntu'
        PackageManager='apt'
    elif grep -Eqi "Raspbian" /etc/issue || grep -Eq "Raspbian" /etc/*-release; then
        Distro='Raspbian'
        PackageManager='apt'
    else
        Distro='unknow'
        PackageManager='unknown'
    fi
    if [[ `getconf WORD_BIT` = '32' && `getconf LONG_BIT` = '64' ]]; then
        OS_Bit='x64'
    else
        OS_Bit='x32'
    fi
	OS_Ver=`/etc/issue | awk '{print $2}'`
	Kernel_Ver=`uname -r`
}

#打印欢迎信息
printWelcome()
{
    printColor yellow '
************服务器初始化预装脚本 -V1.0***********'
    printColor green "
    +---------------------------------------
    |	部署Docker环境，预装宝塔面板
    +---------------------------------------
    |	配置SSH和防火墙，开启网络加速
    +---------------------------------------
    |	当前系统版本：$Distro $OS_Ver $OS_Bit
    +---------------------------------------
    |	当前内核版本：$Kernel_Ver
    +---------------------------------------

"
}

#确认开始部署
confirmOperation()
{
    printColor yellow "即将开启bbr加速、安装Docker-CE，
    配置ssh端口8022，密钥登录、禁止密码登录，
    并配置防火墙、更新系统"
    read -p "是否继续？(y or n)" confirm
    if [ $confirm != 'y' ]; then
        printColor red '终止安装！' >> /dev/stderr
        exit 1
    fi
}

#安装并升级必要系统软件
updateSystem()
{
    if [ $PackageManager = 'apt' ]; then
        apt-get update -y
        apt-get upgrade -y
        apt-get install -y wget curl net-tools tcl tk expect sudo ufw
    fi
    if [ $PackageManager = 'yum' ]; then
        yum update -y
        yum upgrade -y
        yum install -y wget curl net-tools.x86_64 tcl tclx tcl-devel expect sudo
    fi
}

#安装DockerCE环境
installDockerCE()
{
    printColor yellow '检查Docker......'
    docker -v
    if [ $? -eq  0 ]; then
        printColor green '检查到Docker已安装!' >> /dev/stderr
    else
        printColor yellow '安装docker环境...'
        if [ $PackageManager = 'apt' ]; then
            printColor yellow 'apt安装docker'
            apt-get install -y apt-transport-https ca-certificates software-properties-common
            if [ $1 = 'aliyun' ]; then
                curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/$Distro/gpg | apt-key add -
                add-apt-repository -y "deb [arch=$(dpkg --print-architecture)] https://mirrors.aliyun.com/docker-ce/linux/$Distro $(lsb_release -cs) stable"
            else
                curl -fsSL https://download.docker.com/linux/$Distro/gpg | apt-key add -
                add-apt-repository -y "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/$Distro $(lsb_release -cs) stable"
            fi
            apt-get update -y
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose
            groupadd docker
            usermod -aG docker ${USER}
            systemctl enable docker
            systemctl restart docker
        fi
        if [ $PackageManager = 'yum' ]; then
            printColor yellow 'yum安装docker'
            yum install -y yum-utils device-mapper-persistent-data lvm2
            if [ $1 = 'aliyun' ]; then
                yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
            else
                yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            fi
            yum update -y
            yum install -y docker-ce docker-ce-cli containerd.io docker-compose
            systemctl enable docker
            systemctl restart docker
        fi
    fi
}

#配置SSH
configSSH()
{
    mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    echo 'Port 8022' >> /etc/ssh/sshd_config
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
    echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
    echo 'ChallengeResponseAuthentication no' >> /etc/ssh/sshd_config
    echo 'UsePAM yes' >> /etc/ssh/sshd_config
    echo 'X11Forwarding yes' >> /etc/ssh/sshd_config
    echo 'PrintMotd no' >> /etc/ssh/sshd_config
    echo 'AcceptEnv LANG LC_*' >> /etc/ssh/sshd_config
    echo 'Subsystem       sftp    /usr/lib/openssh/sftp-server' >> /etc/ssh/sshd_config
    echo 'AuthorizedKeysFile      .ssh/authorized_keys' >> /etc/ssh/sshd_config

    if [ ! -d "~/.ssh" ]; then
        mkdir -p ~/.ssh
    fi
    if [ ! -f "./authorized_keys.pub" ]; then
        ssh-keygen -t rsa -N '' -f '~/.ssh/authorized_keys'
        printColor green "已创建密钥对，但并未禁止密码登录，请稍候自行下载私钥文件 ~/.ssh/authorized_keys\n若要禁止密码登录，请执行 sed 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config 命令"
    else
        cp -rf ./authorized_keys.pub ~/.ssh/authorized_keys
        sed 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
        printColor green "已部署公钥文件authorized_keys.pub\n若要禁止密码登录，请执行 sed 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config 命令"
    fi
    printColor green 'SSH端口已更改为8022'
    systemctl restart sshd
}

#配置防火墙
configFirewalls()
{
    if [ $PackageManager = 'apt' ]; then
        ufw status
        if [ $? -ne 0 ]; then
            apt-get install ufw
        fi
        printColor yellow '正在配置UFW...'
        ufw disable
        echo y | ufw reset
        ufw default deny incoming
        for port in 8022/tcp;
        do ufw allow $port; done
        ufw reload
		echo y | ufw enable
    fi
    if [ $PackageManager = 'yum' ]; then
        firewall-cmd --state
        if [ $? -ne 0 ]; then
            yum install firewalld -y
        fi
        printColor yellow '正在配置firewall...'
        for port in 8022/tcp;
        do echo y | firewall-cmd --zone=public --add-port $port --permanent; done
        firewall-cmd --reload
        systemctl restart firewalld
    fi
}

#配置网络加速
configNetworkSpeeder()
{
    bbr_status=`sysctl -a|grep net.ipv4.tcp_congestion_control|awk '{print $3}'`
    if [ bbr_status = 'bbr' ]; then
        printColor green "已开启bbr"
    else
        printColor yellow "正在开启bbr加速..."
        sysctl -w "net.core.default_qdisc=fq"
        sysctl -w "net.ipv4.tcp_congestion_control=bbr"
        sysctl -p
    fi
}

destroySelf()
{
    if [ destroySelfFlag -ne 0 ]; then
        rm -rf authorized_keys.pub docker_deploy.sh
        /bin/rm $0
    fi
}

main()
{
    destroySelfFlag = 1;
    checkUser
    getSystemInfo
    printWelcome
    confirmOperation
    updateSystem
    installDockerCE
    configSSH
    configFirewalls
    configNetworkSpeeder
    printColor green '安装完成！'
    
}

main
destroySelf
reboot

