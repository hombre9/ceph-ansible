#!/bin/bash

# osd 和 dev 数组
array_osd=(0 1 2)
array_dev=('sdb1' 'sdc1' 'sdd1')

# 得到数组中元素的数量
arrayNum=${#array_osd[@]}

# 创建osd目录
for dir_no in ${array_osd[@]}
do
    mkdir -p /var/lib/ceph/osd/ceph-$dir_no
#    mkdir -p /mnt/journal/ceph-$dir_no		// if filestore, need journal
done

# 格式化磁盘, 并修改磁盘权限
for dev_name in ${array_dev[@]}
do
    mkfs -t xfs -d name=/dev/$dev_name -f
    chown -R ceph:ceph /dev/$dev_name
done

# 挂载磁盘
for ((i=0; i<arrayNum; i++))
do
  mount -noatime /dev/${array_dev[$i]} /var/lib/ceph/osd/ceph-${array_osd[$i]}
done

 开始部署osd
host_name=`hostname`
ceph osd crush add-bucket $host_name host	# 把此节点加入CRUSH图
ceph osd crush move $host_name root=default	# 把此ceph节点放入 default 根下

for osd_num in ${array_osd[@]}
do
    ceph osd create
    ceph-osd -i $osd_num --mkfs --mkkey		# 初始化osd数据目录。此目录必须是空的，默认集群名称是ceph，若不是，需要 --cluster指定
    ceph auth add osd.$osd_num osd 'allow *' mon 'allow rwx' -i /var/lib/ceph/osd/ceph-$osd_num/keyring		# 注册此OSD的密钥
    ceph osd crush add osd.$osd_num 1.0 host=$host_name		# weight set: 1T = 1.0
    ceph osd in $osd_num			# 将osd加入集群
    chown -R ceph:ceph /var/lib/ceph/osd/ceph-$osd_num
#    start ceph-osd id=$osd_num			# start osd for ubuntu
    systemctl start ceph-osd@$osd_num
done

