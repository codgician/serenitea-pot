# Hosts

List of machines managed by this nix flake.

## Adding a new host

Just create a new folder and name it with the new host name. Under the folder, `default.nix` should exist and describe metadata. Check out any existing host for example.

## Naming convention

Version: *0.1-202405*

Host names are named after terms from [Genshin Impact](https://genshin.hoyoverse.com/en/), an open-world adventure game proudly presented by HoYoverse. When naming a new host, following rules should be evaluated one by one:

* Different hosts should be named after different characters. For characters having multiple names, the name of its human appearance should be used.
* For hypervisor-only hosts: name after a region or an unique non-character concept (e.g. *irminsul*, *celestia*). 
* For virtual machines: Name after [*Archon*](https://genshin-impact.fandom.com/wiki/The_Seven) or [*Dragon*](https://genshin-impact.fandom.com/wiki/Dragon). 
  * Resembles immortality, and being able to transform into multiple forms (like how VMs could be migrated across different hosts).
* For baremetals: Name after human or other characters that has normal lifespan.
* For Non-IoT purposed hosts: If running Unix-like OS then name after female characters. Others (including subsystems like WSL) should be named after male characters. 
* For IoT purpose hosts: Name after characters that are not human, archon or dragon. Examples are [*Melusine*](https://genshin-impact.fandom.com/wiki/Melusine) and [*Aranara*](https://genshin-impact.fandom.com/wiki/Aranara).
* Hosts featuring non-x86 architectures (e.g. aarch64 or risc-v family) are preferred to be named after characters from [*Fontaine*](https://genshin-impact.fandom.com/wiki/Fontaine) (or *Fontainians*) or [Descenders](https://genshin-impact.fandom.com/wiki/Descender).
    * Fontaine people are unique due to originating from [*Oceanid*](https://genshin-impact.fandom.com/wiki/Oceanid).
    * Descenders are also unique due to not belonging to this world.