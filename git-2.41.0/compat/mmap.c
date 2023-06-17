#include "../git-compat-util.h"

void *git_mmap(void *start, size_t length, int prot, int flags, int fd, off_t offset)
{
	size_t n = 0;

	if (start != NULL || flags != MAP_PRIVATE || prot != PROT_READ)
		die("Invalid usage of mmap when built with NO_MMAP");

	if (length == 0) {
		errno = EINVAL;
		return MAP_FAILED;
	}

	start = malloc(length);
	if (!start) {
		errno = ENOMEM;
		return MAP_FAILED;
	}

	while (n < length) {
		ssize_t count = xpread(fd, (char *)start + n, length - n, offset + n);

		if (count == 0) {
			memset((char *)start+n, 0, length-n);
			break;
		}

		if (count < 0) {
			free(start);
			errno = EACCES;
			return MAP_FAILED;
		}

		n += count;
	}

	return start;
}

int git_munmap(void *start, size_t length)
{
	free(start);
	return 0;
}
