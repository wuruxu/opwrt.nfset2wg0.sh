# opwrt.nfset2wg0.sh
uci scrip file for openwrt to setup wireguard based VPN

# opwrt.nfset2wg0.sh

## 项目简介

`opwrt.nfset2wg0.sh` 是一个用于 OpenWrt 系统的自动化脚本，旨在简化基于 WireGuard VPN 的网络流量标记与路由配置。通过结合 `dnsmasq`、`WireGuard` 和 `nfset` 功能，实现对特定 IP 地址集合的流量标记，并自动将对应流量路由到 WireGuard 接口 `wg0`，提高网络管理的灵活性和安全性。

## 适用环境

- 运行 OpenWrt 系统的设备
- 需要预先安装并配置以下组件：
  - `dnsmasq`
  - `WireGuard`（内核模块和用户空间工具）
  - `nfset` （nftables 的地址集合功能）

## 功能特点

- 自动检测和设置 `nftables` 地址集合（nfset）
- 标记匹配集合内 IP 的网络流量
- 将标记的流量通过 WireGuard 接口 `wg0` 转发
- 适合构建基于策略的 VPN 流量转发方案
- 简单脚本调用，方便集成到系统启动流程

## 安装与使用

1. 克隆仓库或下载脚本：
   ```bash
   wget https://github.com/wuruxu/opwrt.nfset2wg0.sh/raw/main/opwrt.nfset2wg0.sh
   chmod +x opwrt.nfset2wg0.sh
   ```

2. 确保系统已安装并启用 `dnsmasq`、`wireguard` 和 `nftables`，并且支持 nfset 功能。

3. 根据需要编辑脚本中的配置参数（如地址集合名、接口名等）。

4. 运行脚本：
   ```bash
   ./opwrt.nfset2wg0.sh
   ```

5. 设备重启自动生效。路由器中所有流量会匹配genwgset.sh预置的规则进行分流

## 注意事项

- 脚本默认使用 `wg0` 作为 WireGuard 接口名称，如有不同请自行修改。
- 运行前请备份现有 `nftables` 配置，避免误操作导致网络中断。
- 脚本依赖系统支持 `nft` 命令及相关模块。
- 使用时请确保 WireGuard VPN 已正确配置并可用。
- 需要wireguard节点优选 参考[wgopd](https://github.com/wuruxu/wgopd)
- 需要手机平板等设备回家(无须安装软件)参考[gohome](https://github.com/wuruxu/gohome)

## 贡献和反馈

欢迎提交 issue 或 pull request 进行交流和改进！

---

**作者**: wuruxu  
**项目地址**: [https://github.com/wuruxu/opwrt.nfset2wg0.sh](https://github.com/wuruxu/opwrt.nfset2wg0.sh)
