#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/in.h>
#include <linux/tcp.h>
#include <linux/udp.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

SEC("cgroup_skb/ingress")
int ingress_filter(struct __sk_buff *skb)
{
    void *data_end = (void *)(long)skb->data_end;
    void *data = (void *)(long)skb->data;
    
    // Check if we have enough data for ethernet header
    if (data + sizeof(struct ethhdr) > data_end)
        return 1; // Allow packet if we can't parse it
    
    struct ethhdr *eth = data;
    
    // Only process IPv4 packets
    if (bpf_ntohs(eth->h_proto) != ETH_P_IP)
        return 1; // Allow non-IP packets
    
    // Check if we have enough data for IP header
    if (data + sizeof(struct ethhdr) + sizeof(struct iphdr) > data_end)
        return 1; // Allow packet if we can't parse IP header
    
    struct iphdr *ip = (void *)(eth + 1);
    
    // Basic packet filtering logic
    // Example: Block packets to port 80 (HTTP)
    if (ip->protocol == IPPROTO_TCP) {
        if (data + sizeof(struct ethhdr) + sizeof(struct iphdr) + sizeof(struct tcphdr) > data_end)
            return 1; // Allow packet if we can't parse TCP header
            
        struct tcphdr *tcp = (void *)(ip + 1);
        __u16 dest_port = bpf_ntohs(tcp->dest);
        
        // Block HTTP traffic (port 80)
        if (dest_port == 80) {
            return 0; // Drop packet
        }
    }
    
    // Allow all other packets
    return 1;
}

char _license[] SEC("license") = "GPL";
