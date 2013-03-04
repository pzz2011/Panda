
#include <string.h>
#include <fs.h>
#include <blk.h>
#include <file.h>

struct devsw devsw[NDEV];

struct file file_buf[NFILE];


void file_init(void) {
    memset(file_buf, 0, sizeof(file_buf));
}

//Allocate a file structure
struct file* file_alloc(void) {
    struct file* f;
    for(f = file_buf; f < file_buf + NFILE; f++) {
        if(f->ref == 0) {
            kassert(f->f_type == FD_NONE);
            f->ref = 1;
            return f;
        }
    }
    return 0;
}

struct file* file_dup(struct file* f) {
    if(f->ref < 1)
        PANIC("file_dup: try to dup a invalid file");
    f->ref++;
    return f;
}

void file_close(struct file* f) {
    if(f->ref < 1)
        PANIC("file_close: try to close a invalid file");
    if(--f->ref > 0){
        return;
    }
    struct file back = *f;
    f->ref = 0;
    f->f_type = FD_NONE;

    if(back.f_type == FD_INODE) {
        iput(back.ip);
    }
}

int file_stat(struct file* f, struct stat* st) {
    if(f->f_type == FD_INODE) {
        stati(f->ip, st);
        return 0;
    }
    return -1;
}

int file_read(struct file* f, char* addr, int n) {
    int r;
    if(f->readable == 0)
        return -1;
    if(f->f_type == FD_INODE) {
        r = readi(f->ip, addr, f->offset, n);
        if(r > 0) {
            f->offset += r;
            return r;
        }
    }
    return -1;
}

int file_write(struct file* f, char* addr, int n) {
    int r;
    if(f->writeable == 0)
        return -1;
    if(f->f_type == FD_INODE) {
        r = writei(f->ip, addr, f->offset, n);
        if( r == n ) {
            f->offset += r;
            return r;
        }
    }
    return -1;
}
