# Hosts

List of machines managed by this nix flake.

## Naming convention

Version: *0.1-202404*

Host names are named after characters from [Genshin Impact](https://genshin.hoyoverse.com/en/), an open-world adventure game proudly presented by HoYoverse. 

* Different hosts should be named after different characters. For characters having multiple names, the name of its human appearance should be used.
* For virtual machines: Name after [*Archon*](https://genshin-impact.fandom.com/wiki/The_Seven) or [*Dragon*](https://genshin-impact.fandom.com/wiki/Dragon).
    * Immortal, and can be transformed into multiple forms (like how VMs could be migrated across different hosts).
* For baremetals: Name after human or other characters that has normal lifespan.
* For Non-IoT purposed hosts: If running Unix-like OS then name after female characters. Others (including subsystems like WSL) should be named after male characters. 
    * This rule does not apply to hosts intending to be hypervisor-only.
* For IoT purpose hosts: Name after characters that are not human, archon or dragon, including but not limited to [*Melusine*](https://genshin-impact.fandom.com/wiki/Melusine) and [*Aranara*](https://genshin-impact.fandom.com/wiki/Aranara).
* Hosts featuring non-x86 architectures (e.g. aarch64 or risc-v family) are preferred to be named after characters from [*Fontaine*](https://genshin-impact.fandom.com/wiki/Fontaine) (or *Fontainians*) or [Descenders](https://genshin-impact.fandom.com/wiki/Descender).
    * Fontaine people are unique due to originating from [*Oceanid*](https://genshin-impact.fandom.com/wiki/Oceanid).
    * Descenders are also unique due to not belonging to this world.