#!/bin/bash

# 遍历 ibdev2netdev 的输出，并对每一个网络设备执行 cma_roce_mode 和 cma_roce_tos 命令，并设置 traffic_class
for dev in $(ibdev2netdev | awk '{print $1}')
do
    echo "正在设置设备 $dev 的 RoCE 模式..."
    cma_roce_mode -d "$dev" -p 1 -m 2
    if [ $? -eq 0 ]; then
        echo "设备 $dev 的 RoCE 模式设置成功！"
    else
        echo "设备 $dev 的 RoCE 模式设置失败，请检查设备或命令是否正确。"
    fi

    echo "正在设置设备 $dev 的 RoCE tos..."
    cma_roce_tos -d "$dev" -t 162
    if [ $? -eq 0 ]; then
        echo "设备 $dev 的 RoCE tos 设置成功！"
    else
        echo "设备 $dev 的 RoCE tos 设置失败，请检查设备或命令是否正确。"
    fi

    # 设置 traffic_class
    tc_path="/sys/class/infiniband/$dev/tc/1/traffic_class"
    if [ -e "$tc_path" ]; then
        echo "正在设置设备 $dev 的 traffic_class..."
        echo 162 > "$tc_path"
        if [ $? -eq 0 ]; then
            echo "设备 $dev 的 traffic_class 设置成功！"
        else
            echo "设备 $dev 的 traffic_class 设置失败，请检查路径或权限是否正确。"
        fi
    else
        echo "设备 $dev 的 traffic_class 路径不存在: $tc_path"
    fi
done

echo "所有设备的 RoCE 设置完成。"

# 获取所有RDMA网口的名称
interfaces=$(ibdev2netdev | awk '{print $5}')

# 遍历每个网口并为其设置QoS
for interface in $interfaces; do
    
    # 设置信任DSCP字段
    echo "正在为网口 $interface 设置信任DSCP字段："
    mlnx_qos -i $interface --trust=dscp

    # 检查上一个命令是否执行成功
    if [ $? -ne 0 ]; then
        echo "在$interface上设置DSCP字段信任时出错"
        exit 1
    fi

    # 设置优先级为strict
    echo "正在为网口 $interface 设置strict优先级："
    mlnx_qos -i $interface -s strict,strict,strict,strict,strict,strict,strict,strict

    # 再次检查命令执行状态
    if [ $? -ne 0 ]; then
        echo "在$interface上设置strict优先级时出错"
        exit 1
    fi

    # 设置PFC值
    echo "正在为网口 $interface 设置PFC值："
    mlnx_qos -i $interface --pfc=0,0,0,0,0,1,0,0

    # 检查命令执行状态
    if [ $? -ne 0 ]; then
        echo "在$interface上设置PFC值时出错"
        exit 1
    fi
done

# 脚本执行完毕，输出总结信息
echo "所有RDMA网口的QoS配置已完成。"
