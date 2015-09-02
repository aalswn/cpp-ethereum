// author Tim Hughes <tim@twistedfury.com>
// Tested on Radeon HD 7850
// Hashrate: 15940347 hashes/s
// Bandwidth: 124533 MB/s
// search kernel should fit in <= 84 VGPRS (3 wavefronts)

#define THREADS_PER_HASH 8
#define HASHES_PER_LOOP (GROUP_SIZE / THREADS_PER_HASH)

#define FNV_PRIME	0x01000193

// #define ROL(V, R)  (R < 32) ? (uint2)(V.x << (R-00) | V.y >> (32-R), V.y << (R-00) | V.x >> (32-R)) \
// 							: (uint2)(V.y << (R-32) | V.x >> (64-R), V.x << (R-32) | V.y >> (64-R))

#define ROL(V, R) as_uint2((as_ulong(V) << R) | as_ulong(V) >> (64-R))

constant ulong Keccak_f1600_RC[24] =
{
	0x0000000000000001, 0x0000000000008082, 0x800000000000808a,
	0x8000000080008000, 0x000000000000808b, 0x0000000080000001,
	0x8000000080008081, 0x8000000000008009, 0x000000000000008a,
	0x0000000000000088, 0x0000000080008009, 0x000000008000000a,
	0x000000008000808b, 0x800000000000008b, 0x8000000000008089,
	0x8000000000008003, 0x8000000000008002, 0x8000000000000080,
	0x000000000000800a, 0x800000008000000a, 0x8000000080008081,
	0x8000000000008080, 0x0000000080000001, 0x8000000080008008
};

constant int keccakf_rotc[24] =
{
	1,  3,  6,  10, 15, 21, 28, 36, 45, 55, 2,  14,
	27, 41, 56, 8,  25, 43, 62, 18, 39, 61, 20, 44
};

constant int keccakf_piln[24] =
{
	10, 7,  11, 17, 18, 3, 5,  16, 8,  21, 24, 4,
	15, 23, 19, 13, 12, 2, 20, 14, 22, 9,  6,  1
};

static void keccak_f1600_round(uint2* a, uint r, uint out_size)
{
   #if !__ENDIAN_LITTLE__
	for (uint i = 0; i != 25; ++i)
		a[i] = a[i].yx;
   #endif

	uint2 b[25];
	uint2 t;

	// Theta
	b[0] = a[0] ^ a[5] ^ a[10] ^ a[15] ^ a[20];
	b[1] = a[1] ^ a[6] ^ a[11] ^ a[16] ^ a[21];
	b[2] = a[2] ^ a[7] ^ a[12] ^ a[17] ^ a[22];
	b[3] = a[3] ^ a[8] ^ a[13] ^ a[18] ^ a[23];
	b[4] = a[4] ^ a[9] ^ a[14] ^ a[19] ^ a[24];

	#pragma unroll
	for (uint i = 0; i < 5; ++i)
	{
		t = b[(i+4)%5] ^ (uint2)(b[(i+1)%5].x << 1 | b[(i+1)%5].y >> 31, b[(i+1)%5].y << 1 | b[(i+1)%5].x >> 31);
		a[0+i] ^= t;
		a[5+i] ^= t;
		a[10+i] ^= t;
		a[15+i] ^= t;
		a[20+i] ^= t;
	}

	// Rho Pi
	b[0]  = a[0];
	b[10] = ROL(a[1] , 1 );
	b[7]  = ROL(a[10], 3 );
	b[11] = ROL(a[7] , 6 );
	b[17] = ROL(a[11], 10);
	b[18] = ROL(a[17], 15);
	b[3]  = ROL(a[18], 21);
	b[5]  = ROL(a[3] , 28);
	b[16] = ROL(a[5] , 36);
	b[8]  = ROL(a[16], 45);
	b[21] = ROL(a[8] , 55);
	b[24] = ROL(a[21], 2 );
	b[4]  = ROL(a[24], 14);
	b[15] = ROL(a[4] , 27);
	b[23] = ROL(a[15], 41);
	b[19] = ROL(a[23], 56);
	b[13] = ROL(a[19], 8 );
	b[12] = ROL(a[13], 25);
	b[2]  = ROL(a[12], 43);
	b[20] = ROL(a[2] , 62);
	b[14] = ROL(a[20], 18);
	b[22] = ROL(a[14], 39);
	b[9]  = ROL(a[22], 61);
	b[6]  = ROL(a[9] , 20);
	b[1]  = ROL(a[6] , 44);

	// Chi
	a[0] = bitselect(b[0] ^ b[2], b[0], b[1]);
	a[1] = bitselect(b[1] ^ b[3], b[1], b[2]);
	a[2] = bitselect(b[2] ^ b[4], b[2], b[3]);
	a[3] = bitselect(b[3] ^ b[0], b[3], b[4]);
	a[4] = bitselect(b[4] ^ b[1], b[4], b[0]);
	a[5] = bitselect(b[5] ^ b[7], b[5], b[6]);
	a[6] = bitselect(b[6] ^ b[8], b[6], b[7]);
	a[7] = bitselect(b[7] ^ b[9], b[7], b[8]);
	a[8] = bitselect(b[8] ^ b[5], b[8], b[9]);
	a[9] = bitselect(b[9] ^ b[6], b[9], b[5]);
	a[10] = bitselect(b[10] ^ b[12], b[10], b[11]);
	a[11] = bitselect(b[11] ^ b[13], b[11], b[12]);
	a[12] = bitselect(b[12] ^ b[14], b[12], b[13]);
	a[13] = bitselect(b[13] ^ b[10], b[13], b[14]);
	a[14] = bitselect(b[14] ^ b[11], b[14], b[10]);
	a[15] = bitselect(b[15] ^ b[17], b[15], b[16]);
	a[16] = bitselect(b[16] ^ b[18], b[16], b[17]);
	a[17] = bitselect(b[17] ^ b[19], b[17], b[18]);
	a[18] = bitselect(b[18] ^ b[15], b[18], b[19]);
	a[19] = bitselect(b[19] ^ b[16], b[19], b[15]);
	a[20] = bitselect(b[20] ^ b[22], b[20], b[21]);
	a[21] = bitselect(b[21] ^ b[23], b[21], b[22]);
	a[22] = bitselect(b[22] ^ b[24], b[22], b[23]);
	a[23] = bitselect(b[23] ^ b[20], b[23], b[24]);
	a[24] = bitselect(b[24] ^ b[21], b[24], b[20]);

	// Iota
	*(ulong*)a ^= Keccak_f1600_RC[r];

   #if !__ENDIAN_LITTLE__
	for (uint i = 0; i != 25; ++i)
		a[i] = a[i].yx;
   #endif
}

#define ROTL64(x, y) (((x) << (y)) | ((x) >> (64 - (y))))

void keccakf(ulong st[25], int rounds)
{
    int i, j, round;
    ulong t, bc[5];

    for (round = 0; round < rounds; round++) {

        // Theta
        for (i = 0; i < 5; i++)
            bc[i] = st[i] ^ st[i + 5] ^ st[i + 10] ^ st[i + 15] ^ st[i + 20];

        for (i = 0; i < 5; i++) {
            t = bc[(i + 4) % 5] ^ ROTL64(bc[(i + 1) % 5], 1);
            for (j = 0; j < 25; j += 5)
                st[j + i] ^= t;
        }

        // Rho Pi
        t = st[1];
        for (i = 0; i < 24; i++) {
            j = keccakf_piln[i];
            bc[0] = st[j];
            st[j] = ROTL64(t, keccakf_rotc[i]);
            t = bc[0];
        }

        //  Chi
        for (j = 0; j < 25; j += 5) {
            for (i = 0; i < 5; i++)
                bc[i] = st[j + i];
            for (i = 0; i < 5; i++)
                st[j + i] ^= (~bc[(i + 1) % 5]) & bc[(i + 2) % 5];
        }

        //  Iota
        st[0] ^= Keccak_f1600_RC[round];
    }
}

#define ROL2L(v, n) (uint2)(v.x << n | v.y >> (32 - n), v.y << n | v.x >> (32 - n))
#define ROL2H(v, n) (uint2)(v.y << (n - 32) | v.x >> (64 - n), v.x  << (n - 32) | v.y >> (64 - n))

void keccak_f1600_round_nvidia(uint2* s, uint r, uint out_size)
{
   #if !__ENDIAN_LITTLE__
	for (uint i = 0; i != 25; ++i)
		s[i] = s[i].yx;
   #endif

	uint2 t[5], u, v;

	/* theta: c = a[0,i] ^ a[1,i] ^ .. a[4,i] */
	t[0] = s[0] ^ s[5] ^ s[10] ^ s[15] ^ s[20];
	t[1] = s[1] ^ s[6] ^ s[11] ^ s[16] ^ s[21];
	t[2] = s[2] ^ s[7] ^ s[12] ^ s[17] ^ s[22];
	t[3] = s[3] ^ s[8] ^ s[13] ^ s[18] ^ s[23];
	t[4] = s[4] ^ s[9] ^ s[14] ^ s[19] ^ s[24];

	/* theta: d[i] = c[i+4] ^ rotl(c[i+1],1) */
	/* theta: a[0,i], a[1,i], .. a[4,i] ^= d[i] */
	u = t[4] ^ ROL2L(t[1], 1);
	s[0] ^= u; s[5] ^= u; s[10] ^= u; s[15] ^= u; s[20] ^= u;
	u = t[0] ^ ROL2L(t[2], 1);
	s[1] ^= u; s[6] ^= u; s[11] ^= u; s[16] ^= u; s[21] ^= u;
	u = t[1] ^ ROL2L(t[3], 1);
	s[2] ^= u; s[7] ^= u; s[12] ^= u; s[17] ^= u; s[22] ^= u;
	u = t[2] ^ ROL2L(t[4], 1);
	s[3] ^= u; s[8] ^= u; s[13] ^= u; s[18] ^= u; s[23] ^= u;
	u = t[3] ^ ROL2L(t[0], 1);
	s[4] ^= u; s[9] ^= u; s[14] ^= u; s[19] ^= u; s[24] ^= u;

	/* rho pi: b[..] = rotl(a[..], ..) */
	u = s[1];

	s[1] = ROL2H(s[6], 44);
	s[6] = ROL2L(s[9], 20);
	s[9] = ROL2H(s[22], 61);
	s[22] = ROL2H(s[14], 39);
	s[14] = ROL2L(s[20], 18);
	s[20] = ROL2H(s[2], 62);
	s[2] = ROL2H(s[12], 43);
	s[12] = ROL2L(s[13], 25);
	s[13] = ROL2L(s[19], 8);
	s[19] = ROL2H(s[23], 56);
	s[23] = ROL2H(s[15], 41);
	s[15] = ROL2L(s[4], 27);
	s[4] = ROL2L(s[24], 14);
	s[24] = ROL2L(s[21], 2);
	s[21] = ROL2H(s[8], 55);
	s[8] = ROL2H(s[16], 45);
	s[16] = ROL2H(s[5], 36);
	s[5] = ROL2L(s[3], 28);
	s[3] = ROL2L(s[18], 21);
	s[18] = ROL2L(s[17], 15);
	s[17] = ROL2L(s[11], 10);
	s[11] = ROL2L(s[7], 6);
	s[7] = ROL2L(s[10], 3);
	s[10] = ROL2L(u, 1);

	// squeeze this in here
	/* chi: a[i,j] ^= ~b[i,j+1] & b[i,j+2] */
	u = s[0]; v = s[1]; s[0] ^= (~v) & s[2];

	/* iota: a[0,0] ^= round constant */

	*(ulong*)s ^= Keccak_f1600_RC[r];
	if (r == 23 && out_size == 4) // we only need s[0]
	{
#if !__ENDIAN_LITTLE__
		s[0] = s[0].yx;
#endif
		return;
	}
	// continue chi
	s[1] ^= (~s[2]) & s[3]; s[2] ^= (~s[3]) & s[4]; s[3] ^= (~s[4]) & u; s[4] ^= (~u) & v;
	u = s[5]; v = s[6]; s[5] ^= (~v) & s[7]; s[6] ^= (~s[7]) & s[8]; s[7] ^= (~s[8]) & s[9];

	if (r == 23) // out_size == 8
	{
#if !__ENDIAN_LITTLE__
		for (uint i = 0; i != 8; ++i)
			s[i] = s[i].yx;
#endif
		return;
	}
	s[8] ^= (~s[9]) & u; s[9] ^= (~u) & v;
	u = s[10]; v = s[11]; s[10] ^= (~v) & s[12]; s[11] ^= (~s[12]) & s[13]; s[12] ^= (~s[13]) & s[14]; s[13] ^= (~s[14]) & u; s[14] ^= (~u) & v;
	u = s[15]; v = s[16]; s[15] ^= (~v) & s[17]; s[16] ^= (~s[17]) & s[18]; s[17] ^= (~s[18]) & s[19]; s[18] ^= (~s[19]) & u; s[19] ^= (~u) & v;
	u = s[20]; v = s[21]; s[20] ^= (~v) & s[22]; s[21] ^= (~s[22]) & s[23]; s[22] ^= (~s[23]) & s[24]; s[23] ^= (~s[24]) & u; s[24] ^= (~u) & v;

#if !__ENDIAN_LITTLE__
	for (uint i = 0; i != 25; ++i)
		s[i] = s[i].yx;
#endif
}

static void keccak_f1600_no_absorb(ulong* a, uint in_size, uint out_size, uint isolate)
{
	for (uint i = in_size; i != 25; ++i)
	{
		a[i] = 0;
	}
#if __ENDIAN_LITTLE__
	a[in_size] ^= 0x0000000000000001;
	a[24-out_size*2] ^= 0x8000000000000000;
#else
	a[in_size] ^= 0x0100000000000000;
	a[24-out_size*2] ^= 0x0000000000000080;
#endif

	// Originally I unrolled the first and last rounds to interface
	// better with surrounding code, however I haven't done this
	// without causing the AMD compiler to blow up the VGPR usage.
	uint r = 0;
	do
	{
		// This dynamic branch stops the AMD compiler unrolling the loop
		// and additionally saves about 33% of the VGPRs, enough to gain another
		// wavefront. Ideally we'd get 4 in flight, but 3 is the best I can
		// massage out of the compiler. It doesn't really seem to matter how
		// much we try and help the compiler save VGPRs because it seems to throw
		// that information away, hence the implementation of keccak here
		// doesn't bother.
		if (isolate)
		{
			keccak_f1600_round((uint2*)a, r, 25);
			++r;
		}
	}
	while (r < 24);
}

#define copy(dst, src, count) for (uint i = 0; i != count; ++i) { (dst)[i] = (src)[i]; }

#define countof(x) (sizeof(x) / sizeof(x[0]))

static uint fnv(uint x, uint y)
{
	//return x * FNV_PRIME ^ y;
	x += (x<<1) + (x<<4) + (x<<7) + (x<<8) + (x<<24);
	return x ^ y;
}

static uint4 fnv4(uint4 x, uint4 y)
{
	return x * FNV_PRIME ^ y;
}

static uint fnv_reduce(uint4 v)
{
	return fnv(fnv(fnv(v.x, v.y), v.z), v.w);
}

typedef union
{
	ulong ulongs[32 / sizeof(ulong)];
	uint uints[32 / sizeof(uint)];
} hash32_t;

typedef union
{
	ulong ulongs[64 / sizeof(ulong)];
	uint  uints [64 / sizeof(uint)];
	uint4 uint4s[64 / sizeof(uint4)];
} hash64_t;

typedef union
{
	uint uints[128 / sizeof(uint)];
	uint4 uint4s[128 / sizeof(uint4)];
} hash128_t;

typedef struct
{
	hash64_t init;
	hash32_t mix;
} hash_state;

static hash64_t init_hash(__constant hash32_t const* header, ulong nonce, uint isolate)
{
	hash64_t init;
	uint const init_size = countof(init.ulongs);
	uint const hash_size = countof(header->ulongs);

	// sha3_512(header .. nonce)
	ulong state[25];
	copy(state, header->ulongs, hash_size);
	state[hash_size] = nonce;
	keccak_f1600_no_absorb(state, hash_size + 1, init_size, isolate);

	copy(init.ulongs, state, init_size);
	return init;
}


static uint inner_loop(uint thread_id, __local hash_state* share, __global hash128_t const* g_dag, uint isolate)
{
	uint init0 = share->init.uints[0];
	uint4 mix = share->init.uint4s[thread_id % 4]; // mix starts from [init init]

	uint a = 0;
	do
	{
		bool update_share = thread_id == (a/4) % THREADS_PER_HASH;

		#pragma unroll 1
		for (uint i = 0; i != 4; ++i)
		{
			if (update_share)
			{
				uint m[4] = { mix.x, mix.y, mix.z, mix.w };
				share->mix.uints[0] = fnv(init0 ^ (a+i), m[i]) % DAG_SIZE;
			}
			barrier(CLK_LOCAL_MEM_FENCE);

			mix = fnv4(mix, g_dag[share->mix.uints[0]].uint4s[thread_id]);
		}
	}
	while ((a += 4) != (ACCESSES & isolate));

	return fnv_reduce(mix);
}


static hash32_t final_hash(hash64_t const* init, hash32_t const* mix, uint isolate)
{
	ulong state[25];

	hash32_t hash;
	uint const hash_size = countof(hash.ulongs);
	uint const init_size = countof(init->ulongs);
	uint const mix_size = countof(mix->ulongs);

	// keccak_256(keccak_512(header..nonce) .. mix);
	copy(state, init->ulongs, init_size);
	copy(state + init_size, mix->ulongs, mix_size);
	keccak_f1600_no_absorb(state, init_size+mix_size, hash_size, isolate);

	// copy out
	copy(hash.ulongs, state, hash_size);
	return hash;
}


static ulong final_hash2(hash_state const* data, uint isolate)
{
	ulong state[25];

	uint const hash_size = sizeof(hash32_t) / sizeof(ulong);
	uint const init_size = countof(data->init.ulongs);
	uint const mix_size = countof(data->mix.ulongs);

	// keccak_256(keccak_512(header..nonce) .. mix);
	copy(state, data->init.ulongs, init_size); //TODO: Eliminate this copy
	copy(state + init_size, data->mix.ulongs, mix_size);
	keccak_f1600_no_absorb(state, init_size+mix_size, hash_size, isolate);

	return state[0];
}


static hash32_t compute_hash_simple(
	__constant hash32_t const* g_header,
	__global hash128_t const* g_dag,
	ulong nonce,
	uint isolate
	)
{
	hash64_t init = init_hash(g_header, nonce, isolate);

	hash128_t mix;
	for (uint i = 0; i != countof(mix.uint4s); ++i)
	{
		mix.uint4s[i] = init.uint4s[i % countof(init.uint4s)];
	}

	uint mix_val = mix.uints[0];
	uint init0 = mix.uints[0];
	uint a = 0;
	do
	{
		uint pi = fnv(init0 ^ a, mix_val) % DAG_SIZE;
		uint n = (a+1) % countof(mix.uints);

		#pragma unroll 1
		for (uint i = 0; i != countof(mix.uints); ++i)
		{
			mix.uints[i] = fnv(mix.uints[i], g_dag[pi].uints[i]);
			mix_val = i == n ? mix.uints[i] : mix_val;
		}
	}
	while (++a != (ACCESSES & isolate));

	// reduce to output
	hash32_t fnv_mix;
	for (uint i = 0; i != countof(fnv_mix.uints); ++i)
	{
		fnv_mix.uints[i] = fnv_reduce(mix.uint4s[i]);
	}

	return final_hash(&init, &fnv_mix, isolate);
}


static ulong compute_hash(
	__local hash_state* shares,
	__constant hash32_t const* g_header,
	__global hash128_t const* g_dag,
	ulong nonce,
	uint isolate
	)
{
	uint const gid = get_global_id(0);
	hash_state s;

	// Compute one init hash per work item.
	s.init = init_hash(g_header, nonce, isolate);

	// Threads work together in this phase in groups of 8.
	uint const thread_id = gid % THREADS_PER_HASH;
	uint const hash_id = (gid % GROUP_SIZE) / THREADS_PER_HASH;
	local hash_state* share = &shares[hash_id];

	#pragma unroll 1
	for (uint i = 0; i < THREADS_PER_HASH; ++i)
	{
		// share init with other threads
		if (i == thread_id)
			share->init = s.init;
		barrier(CLK_LOCAL_MEM_FENCE);

		uint thread_mix = inner_loop(thread_id, share, g_dag, isolate);

		share->mix.uints[thread_id] = thread_mix;
		barrier(CLK_LOCAL_MEM_FENCE);

		if (i == thread_id)
			s.mix = share->mix;
	}
	barrier(CLK_LOCAL_MEM_FENCE);

	return final_hash2(&s, isolate);
}


__attribute__((reqd_work_group_size(GROUP_SIZE, 1, 1)))
__kernel void ethash_search_simple(
	__global volatile uint* restrict g_output,
	__constant hash32_t const* g_header,
	__global hash128_t const* g_dag,
	ulong start_nonce,
	ulong target,
	uint isolate
	)
{
	uint const gid = get_global_id(0);
	hash32_t hash = compute_hash_simple(g_header, g_dag, start_nonce + gid, isolate);

	if (as_ulong(as_uchar8(hash.ulongs[0]).s76543210) < target)
	{
		uint slot = min(convert_uint(MAX_OUTPUTS), convert_uint(atomic_inc(&g_output[0]) + 1));
		g_output[slot] = gid;
	}
}


__attribute__((reqd_work_group_size(GROUP_SIZE, 1, 1)))
__kernel void ethash_search(
	__global volatile uint* restrict g_output,
	__constant hash32_t const* g_header,
	__global hash128_t const* g_dag,
	ulong start_nonce,
	ulong target,
	uint isolate
	)
{
	__local hash_state share[HASHES_PER_LOOP];

	uint const gid = get_global_id(0);
	ulong hash = compute_hash(share, g_header, g_dag, start_nonce + gid, isolate);

	if (as_ulong(as_uchar8(hash).s76543210) < target)
	{
		uint slot = min(convert_uint(MAX_OUTPUTS), atomic_inc(&g_output[0]) + 1);
		g_output[slot] = gid;
	}
}