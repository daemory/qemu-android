/*
 * QEMU HVF support
 *
 * Copyright (c) 2017, Google
 * This software is licensed under the terms of the GNU General Public
 * License version 2, as published by the Free Software Foundation, and
 * may be copied, distributed, and modified under those terms.
 *
 * See the COPYING file in the top-level directory.
 *
 */

#include "sysemu/hvf.h"

int hvf_enabled(void)
{
   return 0;
}

void* hvf_gpa2hva(uint64_t gpa, bool* found) {
    *found = false;
    return 0;
}

uint64_t hvf_hva2gpa(void* hva, bool* found) {
    *found = false;
    return 0;
}
