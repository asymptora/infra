# Inventário de Hardware — Asymptora

## Notebook de Cazuza

**Asus VivoBook X1504VA**

CPU: Intel Core i5-1334U, 10 núcleos (2P + 8E), até 4.6GHz, 12ª geração (Raptor Lake), TDP 15W

GPU: Intel Iris Xe Graphics integrado, 80 Execution Units, memória compartilhada com RAM

RAM: 16GB DDR4 3200MHz

Armazenamento: 512GB SSD

Display: 15.6" FHD 1920x1080 anti-reflexo

Wireless: WiFi 5 (802.11ac), antena 1x1, Bluetooth integrado

Ethernet: ausente (nenhuma porta RJ45)

Portas: 1x USB 3.2 Gen1 Type-C, 1x USB 3.2 Gen1 Type-A, 1x USB 2.0 Type-A, 1x HDMI 1.4, 1x P2 combo áudio

Webcam: integrada

Dimensões: 360.4 x 234.8 x 17.9mm

Peso: aproximadamente 1.7kg

Bateria: 42Wh

Sistema Operacional: Pop!_OS (Linux)

## Notebook de Janaína

**Vaio FE16 VJFE69F11X-B0121H**

CPU: AMD Ryzen 7 5825U, 8 núcleos / 16 threads, 2.0GHz base / 4.5GHz boost, arquitetura Zen 3, TDP 15W

GPU: AMD Radeon Graphics integrado (Zen 3)

RAM: 16GB DDR4 3200MHz, 2 slots SO-DIMM (expansível até 64GB)

Armazenamento: 512GB SSD NVMe

Display: 16" IPS WUXGA 1920x1200, proporção 16:10, anti-reflexo

Wireless: WiFi 6 (802.11ax)

Ethernet: RJ45 integrado

Webcam: 720p HD com shutter mecânico

Microfone: duplo com cancelamento de ruído

Portas: HDMI, USB-A, USB-C, RJ45, P2 combo

Teclado: ABNT2, resistente a respingos, teclado numérico integrado, Ergo Lift

Segurança de hardware: slot Kensington

Bateria: 55Wh, até 10h autonomia, carregador 65W

Dimensões: 359 x 255.3 x 19.8mm

Peso: 1.85kg

Sistema Operacional: Pop!_OS (Linux)

## Server 1 (Homelab)

**Samsung NP350XAA-KF4BR (Essentials E30)**

CPU: Intel Core i3-7020U, dual-core / 4 threads, 2.30GHz, 3MB L3 cache, geração Kaby Lake, TDP 15W

GPU: Intel HD Graphics 620 integrado, memória compartilhada

RAM: 16GB DDR4 (upgrade efetuado; 1 slot SO-DIMM, operação single-channel)

Armazenamento: 1TB HDD SATA 5400 RPM + SSD M.2 SATA 240GB (WD Green, modelo WDS240G0BB-00BJJF0)

Display: 15.6" FHD LED 1920x1080 anti-reflexo, painel TN

Wireless: WiFi 5 (802.11ac), antena 1x1, Bluetooth 4.1

Ethernet: Fast Ethernet RJ45, máximo 10/100 Mbps (não Gigabit)

Portas: 1x HDMI, 2x USB 3.0, 1x USB 2.0, 1x RJ45, 1x P2 combo áudio

Webcam: integrada

Teclado: ABNT2 com teclado numérico integrado

Segurança de hardware: slot Kensington, módulo TPM

Bateria: 43Wh, carregador AC 40W

Dimensões: 377.4 x 248.6 x 19.9mm

Peso: 1.95kg

Sistema Operacional: Proxmox VE 9.2

## Server 2 (Homelab)

**Samsung NP350XAA-KF4BR (Essentials E30)**

CPU: Intel Core i3-7020U, dual-core / 4 threads, 2.30GHz, 3MB L3 cache, geração Kaby Lake, TDP 15W

GPU: Intel HD Graphics 620 integrado, memória compartilhada

RAM: 16GB DDR4 (upgrade efetuado; 1 slot SO-DIMM, operação single-channel)

Armazenamento: 1TB HDD SATA 5400 RPM (slot M.2 disponível, não utilizado)

Display: 15.6" FHD LED 1920x1080 anti-reflexo, painel TN

Wireless: WiFi 5 (802.11ac), antena 1x1, Bluetooth 4.1

Ethernet: Fast Ethernet RJ45, máximo 10/100 Mbps (não Gigabit)

Portas: 1x HDMI, 2x USB 3.0, 1x USB 2.0, 1x RJ45, 1x P2 combo áudio

Webcam: integrada

Teclado: ABNT2 com teclado numérico integrado

Segurança de hardware: slot Kensington, módulo TPM

Bateria: 43Wh, carregador AC 40W

Dimensões: 377.4 x 248.6 x 19.9mm

Peso: 1.95kg

Sistema Operacional: Proxmox VE 9.2

## ONT do ISP

**ZTE ZXHN F6645P**

Tipo: GPON ONT (Optical Network Terminal)

Firmware: V2.0.12P1N8

Modo atual: bridge (NAT + DHCP + WiFi desativados; roteamento feito pelo Cudy WR3000)

Portas WAN: 1x GPON (fibra óptica)

Controle: firmware proprietário Claro, sem acesso root confirmado até desbloqueio

## Roteador

**Cudy WR3000 v1**

CPU: MediaTek MT7981BA (Filogic 820), dual-core ARM Cortex-A53, 1.3GHz

RAM: 256MB DDR3L

Flash: 16MB SPI NOR

WiFi: AX3000 dual-band

2.4GHz: 802.11ax 2x2 MIMO, até 574Mbps

5GHz: 802.11ax 2x3 MIMO, 160MHz, até 2402Mbps

Antennas: 4 fixas omnidirecionais externas

Portas: 1x WAN Gigabit (1GbE) + 3x LAN Gigabit (1GbE)

Aceleração de hardware: WED (Wireless Ethernet Driver) para offload de pacotes

Consumo: 7.5W máximo, 3.6W idle

Fonte: 12V / 1A DC

Dimensões: 200 x 120 x 35mm

Peso: 295g

Sistema Operacional: OpenWrt 25.12.5

Status: configurado e operando

## Celulares (2 unidades)


**Higor**: Samsung Android Galaxy A31s

**Janaína**: Samsung Android Galaxy A17 5G

## IoT

Amazon Fire TV Stick — geração específica não informada.

## Pendências de auditoria

- [ ] Confirmar quantidade exata de portas LAN da ONT (verificar via nmap)
- [ ] Confirmar especificações exatas do WiFi da ONT (consultar painel do dispositivo)
- [ ] Confirmar geração do Amazon Fire TV Stick
