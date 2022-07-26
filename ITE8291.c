#include <unistd.h>
#include <stdio.h>
#include <err.h>
#include <string.h>
#include <dirent.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <linux/hidraw.h>

int ExistIO(char *io)
{
	int r = 0;
	FILE *f = fopen("/proc/iomem", "r");
	if(!f) return r;
	do {
		char l[0x100];
		if(fgets(l, sizeof(l), f))
			if(strstr(l, io)) r = 1;
	} while(!r && !feof(f));
	fclose(f);
	return r;
}

int SetAP(off_t addr, char set)
{
	int r = 0;
	int f = open("/dev/mem", O_RDWR | O_SYNC);
	if(f < 0) return r;
	size_t p = sysconf(_SC_PAGE_SIZE);
	off_t b = addr / p * p;
	off_t o = addr - b;
	char *m = mmap(NULL, o + 1, PROT_READ | PROT_WRITE, MAP_SHARED, f, b);
	if((r = (m != MAP_FAILED))) {
		//if((r = !!(m[o] & 0x80)))
			m[o] = set ? m[o] | 0x01 : m[o] & 0xFE;
		munmap(m, o + 1);
	}
	close(f);
	return r;
}

int set_timeout(int dev, char enable, char time, char save)
{
	char buf[9] = {0x00, 0x1A, 0x00, enable, time, 0x00, 0x00, 0x00, save};
	int ret = ioctl(dev, HIDIOCSFEATURE(sizeof(buf)), buf);
	if(ret < 0) warn("set_timeout -> ioctl");
	return ret;
}

int set_brightness(int dev, char brightness, char save)
{
	char buf[9] = {0x00, 0x09, 0x02, brightness, 0x00, 0x00, 0x00, 0x00, save};
	int ret = ioctl(dev, HIDIOCSFEATURE(sizeof(buf)), buf);
	if(ret < 0) warn("set_brightness -> ioctl");
	return ret;
}

int set_color(int dev, char i, char r, char g, char b, char save) //custom
{
	char buf[9] = {0x00, 0x14, 0x00, i, r, g, b, 0x00, save};
	int ret = ioctl(dev, HIDIOCSFEATURE(sizeof(buf)), buf);
	if(ret < 0) warn("set_color -> ioctl");
	return ret;
}

int set_effect(int dev,
	char control,    //0x01(off), 0x02(default), 0x03(welcome), 0x04(night)
	char mode,       //0x01(static), 0x02(breathing), 0x03(wave), 0x04(reactive), 0x05(custom/rainbow), 0x06(ripple), 0x07(raindrop), 0x08(neon), 0x09(marquee), 0x0A(stack), 0x0B(impact), 0x0C(spark), 0x0D(aurora)
	char speed,      //0x00 ~ 0x0A
	char brightness, //0x08, 0x16, 0x24, 0x32
	char color,      //0x01(red), 0x02(orange), 0x03(yellow), 0x04(green), 0x05(blue), 0x06(teal), 0x07(purple), 0x08(custom/rainbow)
	char mode2,      //0x01(leftright), 0x02(rightleft), 0x03(downup), 0x04(updown)
	char save)
{
	char buf[9] = {0x00, 0x08, control, mode, speed, brightness, color, mode2, save};
	int ret = ioctl(dev, HIDIOCSFEATURE(sizeof(buf)), buf);
	if(ret < 0) warn("set_effect -> ioctl");
	return ret;
}

int open_device(short vendor, short product)
{
	int r = -1;

	DIR *dir;
	if(!(dir = opendir("/dev"))) {
		warn("open_device -> opendir(/dev)");
		return r;
	}

	struct dirent *ent;
	while((ent = readdir(dir))) {
		if(strncmp(ent->d_name, "hidraw", 6)) continue;

		int dev = openat(dirfd(dir), ent->d_name, O_RDWR | O_NONBLOCK);
		if(dev < 0) continue;

		struct hidraw_devinfo info;
		if(ioctl(dev, HIDIOCGRAWINFO, &info) >= 0 && info.vendor == vendor && info.product == product) {
			r = dev;
			break;
		}

		close(dev);
	}

	closedir(dir);

	return r;
}

int main(void)
{
	if(getuid()) {
		warnx("You need to be root...");
		return 0;
	}

	int dev;
	if((dev = open_device(0x048d, 0xce00)) >= 0) {
		if(ExistIO("fe410000-fe410fff : INOU0000:00")) SetAP(0xfe410741, 1);
		set_timeout(dev, 1, 0x04, 1);
		set_brightness(dev, 0x24, 1);
		set_color(dev, 1, 0x25, 0x00, 0xDA, 1);
		set_color(dev, 2, 0x00, 0x00, 0xFF, 1);
		set_color(dev, 3, 0x00, 0x00, 0xFF, 1);
		set_color(dev, 4, 0x25, 0x00, 0xDA, 1);
		set_color(dev, 5, 0x00, 0x00, 0xFF, 1);
		set_color(dev, 6, 0x25, 0x00, 0xDA, 1);
		set_color(dev, 7, 0x00, 0x00, 0xFF, 1);
		set_effect(dev, 0x02, 0x05, 0x05, 0x24, 0x08, 0x00, 1);
		close(dev);
	}
	if((dev = open_device(0x048d, 0x6005)) >= 0) {
		set_brightness(dev, 0x16, 1);
		set_color(dev, 1, 0x55, 0x00, 0xAA, 1);
		set_color(dev, 2, 0x33, 0x00, 0xCC, 1);
		set_color(dev, 3, 0x11, 0x00, 0xEE, 1);
		set_color(dev, 4, 0x00, 0x00, 0xFF, 1);
		set_color(dev, 5, 0x11, 0x00, 0xEE, 1);
		set_color(dev, 6, 0x33, 0x00, 0xCC, 1);
		set_color(dev, 7, 0x55, 0x00, 0xAA, 1);
		set_effect(dev, 0x02, 0x05, 0x05, 0x16, 0x08, 0x00, 1);
		close(dev);
	}
	return 0;
}
