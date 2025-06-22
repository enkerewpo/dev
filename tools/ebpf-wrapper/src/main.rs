use aya::programs::{CgroupAttachMode, CgroupSkb, CgroupSkbAttachType};
use aya::Ebpf;
use std::fs::File;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Set up signal handling
    let running = Arc::new(AtomicBool::new(true));
    let r = running.clone();
    
    ctrlc::set_handler(move || {
        println!("Received interrupt signal, shutting down...");
        r.store(false, Ordering::SeqCst);
    })?;

    println!("Loading eBPF program...");
    
    // load the BPF code
    let mut ebpf = Ebpf::load_file("ebpf1.o")?;

    // get the `ingress_filter` program compiled into `ebpf1.o`.
    let ingress: &mut CgroupSkb = ebpf.program_mut("ingress_filter").ok_or("Program not found")?.try_into()?;

    println!("Loading program into kernel...");
    
    // load the program into the kernel
    ingress.load()?;

    println!("Attaching program to cgroup...");
    
    // attach the program to the root cgroup. `ingress_filter` will be called for all
    // incoming packets.
    let cgroup = File::open("/sys/fs/cgroup/unified")?;
    ingress.attach(
        cgroup,
        CgroupSkbAttachType::Ingress,
        CgroupAttachMode::AllowOverride,
    )?;

    println!("eBPF program loaded and attached successfully!");
    println!("Filtering incoming packets (blocking HTTP traffic on port 80)...");
    println!("Press Ctrl+C to exit");

    // Keep the program running
    while running.load(Ordering::SeqCst) {
        thread::sleep(Duration::from_secs(1));
    }

    println!("Cleaning up...");
    Ok(())
}
