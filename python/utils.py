def gen_set_bit_vals(n):
	while n:
		set_bit = n ^ (n&(n-1))
		yield set_bit
		n = ~set_bit & n


def test_gen_set_bit_vals():
	assert list(gen_set_bit_vals(8)) == [8]
	assert list(gen_set_bit_vals(15)) == [1,2,4,8]
	assert list(gen_set_bit_vals(13)) == [1,4,8]


def main():
	test_gen_set_bit_ixs()


if __name__ == '__main__':
	main()
