This repository is supposed to be used as a framework for demonstrating image-builder functionality.

1. Use of 3rd-party repos
2. Version upgrades as versions advance
3. Package additions as versions advance
4. Add user, with Password and ssh-key
5. Demonstrate greenboot functionality

Prereqs on the build box:
cockpit
cockpit-machines
cockpit-podman
podman
jq (useful, not critical)
tree (useful, not critical)

When working with VMs hosted on one machine, it is easiest to set them up using the graphical cockpit UI, but when demoing what their content is, it is easier to use virsh. There's anote at the bottom about that.


What needs to be done after downloading the repo. (Sometimes problems can happen if you don't use sudo. Once you start using sudo, all the files get tagged with root so... your sort of stuck in sudo-land after that point anyways)

## PART 1: Get a customized iso file
Relevant doc links
https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/composing_installing_and_managing_rhel_for_edge_images/composing-a-rhel-for-edge-image-using-image-builder-command-line_composing-installing-managing-rhel-for-edge-images#doc-wrapper
https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/composing_installing_and_managing_rhel_for_edge_images/composing-a-rhel-for-edge-image-using-image-builder-command-line_composing-installing-managing-rhel-for-edge-images#creating-a-rhel-for-edge-installer-image-using-command-line-interface-for-non-network-based-deployments_composing-a-rhel-for-edge-image-using-image-builder-command-line

PART 1 is the foundational knowledge. If you haven't done this before it could take days to get right, because: composer-builds take 20-30 minutes and rhel installs take 45 minutes. So, cycling on errors / mistakes takes a long time. I think getting PART 1 good for someone who knows what's up would take, on average 2 or 3 hours. Just because of the cycle time for correcting small errors.

1. Create an ssh key using ssh-keygen and store both parts in the keys directory. Also, make sure the public part is one-line, and add it in the right place in the 3 nginx.toml files and (if you want) the user file 

2. Create an encrypted password for the user and put in the three nginx.toml files and (if you want) the user file.

3. add the epel file to composer-cli sources

4. start w/v1. push the .toml file to composer-cli blueprints (e.g. composer-cli blueprints push /path/to/nginx.toml)

5. build an edge-container image, with a "ref" param to start it: e.g. composer-cli compose start-ostree nginx edge-container --ref my-ref

6. pull down the result (composer-cli compose results UUID), I've added folders to pull those results to, because, honestly, it can get pretty messy pretty quick with all the guids.

7. extract the result (tar -xvf UUID.tar) , import into podman (cat UUID-container.tar | sudo podman load) maybe you don't need the sudo, but I've had problems without it.

8. tag the new image in podman (podman tag localhost/my-tag-probably-nginx-container:1.0.0 IMAGE-UUID)

9. host the image in podman, punching a route to 8080 on the container (podman run -d -p 8085:8080 localhost/my-tag-probably-nginx-container:1.0.0)

8. buld an edge-installer image, with the same "ref" param, and url = localhost:8085 (port same as the line above, where you exposed 8080) example: composer-cli compose start-ostree nginx --ref my-ref --url http://123.456.789.123:8085/repo edge-installer
8.a. the "/repo" part is important, if you get the ref, url, port, or /repo part wrong, the composer should error out (quickly!) and tell you it can't find the ref
8.b. when I run this demo all-on-one-box, I use (ip addr) and look for the inet address in the vibr0 section and use that. I assume that's the IP address all the guest vms can see

9. pull down the result (composer-cli compose results UUID), and extract it (tar -xvf UUID.tar), and move the .iso file to somewhere easy to access (I make a root directory "/vms" and put the isos there).

First part done, you have an iso!

### PART 1 Test

10. Test it by going to the cocpit GUI, and Virtual Machines, launch a new VM, using a local install media, then browse to  /vms/, then, when the locations reads "/vms", hit the dropdown again to see your UUID.iso file that the UI discovered. Everything else can be default, I like to double the disk and 4x the RAM, but whatever.

11. Things that should work: you should be able to log in with your user, using either the ssh key that you stored in the keys directory (step 1), or using the password (step 2). The user should have sudo access as part of the wheel group.

12. The actual rpm-ostree will be wrong. I'm not sure if this is a bug, seems like a bug. Check it out at /etc/ostree/remotes.d/rhel, there's a url in there that probably points to fil:///something/something. Change that to be url=http://123.456.789.123:8085/repo . At this point the command rpm-ostree upgrade --check should work (that is : not-error, there won't be any upgrades at this time in the process)

## PART 2 Get an edge update to work:
Relevant docs:
https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/composing_installing_and_managing_rhel_for_edge_images/edge-terminology-and-commands_composing-installing-managing-rhel-for-edge-images#rpm-ostree-commands_edge-terminology-and-commands
https://docs.fedoraproject.org/en-US/iot/applying-updates-UG/
want to try automatic updates? https://miabbott.github.io/2018/06/13/rpm-ostree-automatic-updates.html


13. push v2/nginx.toml file to composer-cli blueprints (e.g. composer-cli blueprints push /path/to/v2/nginx.toml )

14. build an edge-container image, with --ref and --url correct (composer-cli compose start-ostree nginx edge-container --ref my-ref --url http://123.456.789.123:8085/repo edge-commit) as before, if you get the url, port, ref, or  forget to add the /repo suffix, it will error quickly

15. download the edge-container results (composer-cli compose results UUID), extract it (tar -xvf UUID.tar), push the image to podman (cat UUID-container.tar | podman load), tag the image (podman tag localhost/my-tag-probably-nginx-container:2.0.0 IMAGE-UUID).

16. kill the old container (podman ps -a ; podman kill OLD-CONTANER-UUID), start the new one on the same port (podman run -d -p 8085:8080 localhost/my-tag-probably-ngnix-container:2.0.0)

Upgrade hosted, now check it on the guest vm.

17. On the guest vm, rpm-ostree upgrade --check. You should see an upgrade available! rpm-ostre upgrade, will download it and you can see it once it's downloaded. rpm-ostree upgrade -r will download it AND reboot the box and apply the upgrade. Either way, after the box is rebooted, you can do rpm-ostree status and show that you're on the lastest version.

18. (rpm-ostree status) then (rpm-ostree db diff uuid-1 uuid-2) will show the diffs nicely. While composer-cli needs the FULL UUID, rpm-ostree seems to be able to handle first-4-characters of the UUID, which is nice.

PART 2 done, you have successfully upgraded from v1, to v2

## PART 3 - Greenboot!
Relevant docs: https://github.com/fedora-iot/greenboot

19. Downgrade the guest vm (rpm-ostree downgrade -r), because you want to check greenboot. The way to demo greenboot is to create a fake crash dump and show the upgrade doesn't happen when the file exists.

20. In otherscripts there's a script to create the crash dump directory (mkdir /var/dumps), a lot of this stuff is in otherscripts.

21. On edge vm, add check-dumps.sh to /etc/greenboot/check/required.d , it doesn't have to chmodded to an executable. Also add bootfaill.sh to /etc/greenboot/red.d. Check-dumps checks the /var/dumps directory for *.dump files, and bootfail writes a note to a log about what happened.

22. Create a "dump" file (touch /var/dumps/bad-crash.dump). Then upgrade the box (rpm-ostree upgrade -r). The box will reboot 3 times, before rolling back, so this will take a while. Probably... figure out a way to reduce that reboot-3-times cycle. Eventually when the box is available again, show it's on v1, and that there's stuff in the log.

23. If you want, delete the dump file, and do rpm-ostree upgrade -r again, watch the magic.

Part 3 done!

## PART 4 - If you want, get the actual initial install to work seamlessly. 
Honestly, this isn't going to be part of a demo. Installing an OS takes forever and everyone knows this, so starting the demo with "I already created all the test machines to save time." is a pretty reasonable strategy. But if YOU want to do it to keep yourself honest, here's what I have to do.

1. Host a kickstart file, which includes ostree params.
2. Run the install with both the  kickstart file AND the v1 version of the image commit available AND running from the custom iso. Honestly, I don't know if all 3 of these are required... technically if the iso has all the packages then you don't need the hosted image commit right?

1. Following the steps here with some modifications:
https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html-single/composing_installing_and_managing_rhel_for_edge_images/index#setting-up-a-web-server-to-install-rhel-for-edge-image_installing-rpm-ostree-images

2. Put some-tar-any-tar file in the /kspods directory. We're just using it so that the container hosting the kickstarter file will build properly, and then ignoring it. I know this is a hack, eventually I'll sort it out.

3. The kickstarter is different from what's at the RH link, it's shorter, doesn't include an extra user creation. It includes an un-encrypted root password, something I need to fix, but tha parameter is needed to get the install to go end-to-end w/out stopping for user input. Note the kistarter file in the RH documentation has a --url parameter on the ostreesetup line that is https://. This isn't going to work without some certs somewhere, edit that to be http:// instead. Also note the ostreeparams line has to be one line.

4. Build the pod (podman build -t localhost/kshost --build-arg commit=UUID-commit.tar .

5. Host the pod (podman run --rm -d -p 8080:8080 localhost/kshost). Note: here we're going to expose the pod on port 8080, not 8085 like the others. Also note: the kickstart.ks file references the ostree --url as http:// not https://.

6. Once the pod is running, test it with  (curl http://123.456.789.123:8080/kickstart.ks) (with 123.456.789.123 being the ip-address of the host on the vibr0 network). You should see the kickstart.ks file

7. Kick off a new vm, pointing to the iso you built in part one. As the build starts, click [tab] to edit the kernel parameters to be: inst.ks=http://123.456.789.123:8080/kickstart.ks. It should build without error and, critically, have the url correct in /etc/ostree/remotes.d/rhel.


Note about demoing with the various VMs.
When setting up the VMs, graphical all the way with the cockpit UI. Very easy to understand, etc.
But, when demoing what's actually happening on the edge devices, the cmd line is easier, since you will be :
a. showing "status" info
b. doing diffs between commits
c. showing configuration file contents and logs contents
It's better to do this via the demo-machine's shell window, since the shell holds a history of all the commands, and you can scroll-up on the screen to see some output from a previous command. Yes, cockpit has a window for Terminal access, but it doesn't have that scroll-up capability across multiple guest VMs that a shell on the main demoing laptop has.

The two commands you need to know are:
sudo virsh list (show all the running vms)
sudo virsh domifaddr my-vm-name (show the ipaddress of my vm)
Then you can (ssh user@my-vm-ipaddress -i keys/my_rsa) to log in via a shell

