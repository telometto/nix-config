{ lib, grafana }:

{
  panels = [
    # Row header - collapsed by default
    (grafana.mkRow {
      title = "Memory Meminfo";
      id = 266;
      collapsed = true;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        y = 21;
      };
    })

    # Memory Committed
    (grafana.mkTimeseries {
      title = "Memory Committed";
      id = 135;
      description = "Displays committed memory usage versus the system's commit limit. Exceeding the limit is allowed under Linux overcommit policies but may increase OOM risks under high load";
      unit = "bytes";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 732;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_Committed_AS_bytes{instance="$node",job="$job"}'';
          legendFormat = "Committed_AS – Memory promised to processes (not necessarily used)";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_CommitLimit_bytes{instance="$node",job="$job"}'';
          legendFormat = "CommitLimit - Max allowable committed memory";
          refId = "B";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

    # Memory Writeback and Dirty
    (grafana.mkTimeseries {
      title = "Memory Writeback and Dirty";
      id = 130;
      description = "Memory currently dirty (modified but not yet written to disk), being actively written back, or held by writeback buffers. High dirty or writeback memory may indicate disk I/O pressure or delayed flushing";
      unit = "bytes";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 732;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_Writeback_bytes{instance="$node",job="$job"}'';
          legendFormat = "Writeback – Memory currently being flushed to disk";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_WritebackTmp_bytes{instance="$node",job="$job"}'';
          legendFormat = "WritebackTmp – FUSE temporary writeback buffers";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_Dirty_bytes{instance="$node",job="$job"}'';
          legendFormat = "Dirty – Memory marked dirty (pending write to disk)";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_NFS_Unstable_bytes{instance="$node",job="$job"}'';
          legendFormat = "NFS Unstable – Pages sent to NFS server, awaiting storage commit";
          refId = "D";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

    # Memory Slab
    (grafana.mkTimeseries {
      title = "Memory Slab";
      id = 131;
      description = "Kernel slab memory usage, separated into reclaimable and non-reclaimable categories. Reclaimable memory can be freed under memory pressure (e.g., caches), while unreclaimable memory is locked by the kernel for core functions";
      unit = "bytes";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 932;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_SUnreclaim_bytes{instance="$node",job="$job"}'';
          legendFormat = "SUnreclaim – Non-reclaimable slab memory (kernel objects)";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_SReclaimable_bytes{instance="$node",job="$job"}'';
          legendFormat = "SReclaimable – Potentially reclaimable slab memory (e.g., inode cache)";
          refId = "B";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

    # Memory Shared and Mapped
    (grafana.mkTimeseries {
      title = "Memory Shared and Mapped";
      id = 138;
      description = "Memory used for mapped files (such as libraries) and shared memory (shmem and tmpfs), including variants backed by huge pages";
      unit = "bytes";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 932;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_Mapped_bytes{instance="$node",job="$job"}'';
          legendFormat = "Mapped – Memory mapped from files (e.g., libraries, mmap)";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_Shmem_bytes{instance="$node",job="$job"}'';
          legendFormat = "Shmem – Shared memory used by processes and tmpfs";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_ShmemHugePages_bytes{instance="$node",job="$job"}'';
          legendFormat = "ShmemHugePages – Shared memory (shmem/tmpfs) allocated with HugePages";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_ShmemPmdMapped_bytes{instance="$node",job="$job"}'';
          legendFormat = "PMD Mapped – Shmem/tmpfs backed by Transparent HugePages (PMD)";
          refId = "D";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

    # Memory LRU Active / Inactive (%)
    (grafana.mkTimeseries {
      title = "Memory LRU Active / Inactive (%)";
      id = 136;
      description = "Proportion of memory pages in the kernel's active and inactive LRU lists relative to total RAM. Active pages have been recently used, while inactive pages are less recently accessed but still resident in memory";
      unit = "percentunit";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 942;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''
            (node_memory_Inactive_bytes{instance="$node",job="$job"}) 
            / 
            (node_memory_MemTotal_bytes{instance="$node",job="$job"})'';
          legendFormat = "Inactive – Less recently used memory, more likely to be reclaimed";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''
            (node_memory_Active_bytes{instance="$node",job="$job"}) 
            / 
            (node_memory_MemTotal_bytes{instance="$node",job="$job"})
          '';
          legendFormat = "Active – Recently used memory, retained unless under pressure";
          refId = "B";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

    # Memory LRU Active / Inactive Detail
    (grafana.mkTimeseries {
      title = "Memory LRU Active / Inactive Detail";
      id = 191;
      description = "Breakdown of memory pages in the kernel's active and inactive LRU lists, separated by anonymous (heap, tmpfs) and file-backed (caches, mmap) pages.";
      unit = "bytes";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 942;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_Inactive_file_bytes{instance="$node",job="$job"}'';
          legendFormat = "Inactive_file - File-backed memory on inactive LRU list";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_Inactive_anon_bytes{instance="$node",job="$job"}'';
          legendFormat = "Inactive_anon – Anonymous memory on inactive LRU (incl. tmpfs & swap cache)";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_Active_file_bytes{instance="$node",job="$job"}'';
          legendFormat = "Active_file - File-backed memory on active LRU list";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_Active_anon_bytes{instance="$node",job="$job"}'';
          legendFormat = "Active_anon – Anonymous memory on active LRU (incl. tmpfs & swap cache)";
          refId = "D";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

    # Memory Kernel / CPU / IO
    (grafana.mkTimeseries {
      title = "Memory Kernel / CPU / IO";
      id = 160;
      description = "Tracks kernel memory used for CPU-local structures, per-thread stacks, and bounce buffers used for I/O on DMA-limited devices. These areas are typically small but critical for low-level operations";
      unit = "bytes";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 952;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_KernelStack_bytes{instance="$node",job="$job"}'';
          legendFormat = "KernelStack – Kernel stack memory (per-thread, non-reclaimable)";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_Percpu_bytes{instance="$node",job="$job"}'';
          legendFormat = "PerCPU – Dynamically allocated per-CPU memory (used by kernel modules)";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_Bounce_bytes{instance="$node",job="$job"}'';
          legendFormat = "Bounce Memory – I/O buffer for DMA-limited devices";
          refId = "C";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

    # Memory Vmalloc
    (grafana.mkTimeseries {
      title = "Memory Vmalloc";
      id = 70;
      description = "Usage of the kernel's vmalloc area, which provides virtual memory allocations for kernel modules and drivers. Includes total, used, and largest free block sizes";
      unit = "bytes";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 952;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_VmallocChunk_bytes{instance="$node",job="$job"}'';
          legendFormat = "Vmalloc Free Chunk – Largest available block in vmalloc area";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_VmallocTotal_bytes{instance="$node",job="$job"}'';
          legendFormat = "Vmalloc Total – Total size of the vmalloc memory area";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_VmallocUsed_bytes{instance="$node",job="$job"}'';
          legendFormat = "Vmalloc Used – Portion of vmalloc area currently in use";
          refId = "C";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

    # Memory Anonymous
    (grafana.mkTimeseries {
      title = "Memory Anonymous";
      id = 129;
      description = "Memory used by anonymous pages (not backed by files), including standard and huge page allocations. Includes heap, stack, and memory-mapped anonymous regions";
      unit = "bytes";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 962;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_AnonHugePages_bytes{instance="$node",job="$job"}'';
          legendFormat = "AnonHugePages – Anonymous memory using HugePages";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_AnonPages_bytes{instance="$node",job="$job"}'';
          legendFormat = "AnonPages – Anonymous memory (non-file-backed)";
          refId = "B";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

    # Memory Unevictable and MLocked
    (grafana.mkTimeseries {
      title = "Memory Unevictable and MLocked";
      id = 137;
      description = "Memory that is locked in RAM and cannot be swapped out. Includes both kernel-unevictable memory and user-level memory locked with mlock()";
      unit = "bytes";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 962;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_Unevictable_bytes{instance="$node",job="$job"}'';
          legendFormat = "Unevictable – Kernel-pinned memory (not swappable)";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_Mlocked_bytes{instance="$node",job="$job"}'';
          legendFormat = "Mlocked – Application-locked memory via mlock()";
          refId = "B";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

    # Memory DirectMap
    (grafana.mkTimeseries {
      title = "Memory DirectMap";
      id = 128;
      description = "How much memory is directly mapped in the kernel using different page sizes (4K, 2M, 1G). Helps monitor large page utilization in the direct map region";
      unit = "bytes";
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 972;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_DirectMap1G_bytes{instance="$node",job="$job"}'';
          legendFormat = "DirectMap 1G – Memory mapped with 1GB pages";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_DirectMap2M_bytes{instance="$node",job="$job"}'';
          legendFormat = "DirectMap 2M – Memory mapped with 2MB pages";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_DirectMap4k_bytes{instance="$node",job="$job"}'';
          legendFormat = "DirectMap 4K – Memory mapped with 4KB pages";
          refId = "C";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

    # Memory HugePages
    (grafana.mkTimeseries {
      title = "Memory HugePages";
      id = 140;
      description = "Displays HugePages memory usage in bytes, including allocated, free, reserved, and surplus memory. All values are calculated based on the number of huge pages multiplied by their configured size";
      unit = "bytes";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 972;
      };
      targets = [
        (grafana.mkTarget {
          expr = ''node_memory_HugePages_Free{instance="$node",job="$job"} * node_memory_Hugepagesize_bytes{instance="$node",job="$job"}'';
          legendFormat = "HugePages Used – Currently allocated";
          refId = "A";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_HugePages_Rsvd{instance="$node",job="$job"} * node_memory_Hugepagesize_bytes{instance="$node",job="$job"}'';
          legendFormat = "HugePages Reserved – Promised but unused";
          refId = "B";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_HugePages_Surp{instance="$node",job="$job"} * node_memory_Hugepagesize_bytes{instance="$node",job="$job"}'';
          legendFormat = "HugePages Surplus – Dynamic pool extension";
          refId = "C";
          instant = false;
        })
        (grafana.mkTarget {
          expr = ''node_memory_HugePages_Total{instance="$node",job="$job"} * node_memory_Hugepagesize_bytes{instance="$node",job="$job"}'';
          legendFormat = "HugePages Total – Reserved memory";
          refId = "D";
          instant = false;
        })
      ];
      options = {
        legend = {
          calcs = [
            "min"
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "none";
        };
      };
      fieldConfig = {
        defaults = {
          custom.fillOpacity = 20;
          min = 0;
        };
      };
    })

  ];
}
