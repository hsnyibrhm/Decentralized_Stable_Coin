# Decentralized Stable Coin (DSC)

Proyek Foundry ini berisi token ERC-20 DSC dan `DSCEngine`, kontrak yang mencatat collateral, utang DSC, dan likuidasi. DSC ditujukan untuk mempertahankan nilai sekitar USD 1 dengan dukungan collateral berlebih; peg tidak dijamin atau dipertahankan oleh mekanisme pasar eksternal.

## Cara kerja dan parameter

- Pengguna menyetor token collateral yang didaftarkan saat deployment, lalu dapat mencetak DSC selama faktor kesehatan akun tetap minimal `1e18` (1.0).
- Nilai collateral dijumlahkan dalam USD. Ambang collateral untuk perhitungan faktor kesehatan adalah 50%; bonus collateral likuidasi adalah 10%.
- Pengguna dapat membakar DSC untuk mengurangi utang dan menebus collateral. Likuidator dapat melunasi utang akun dengan faktor kesehatan di bawah 1.0 dan menerima collateral beserta bonus, jika faktor kesehatan akun yang dilikuidasi membaik. Jika collateral yang dibutuhkan untuk pelunasan beserta bonus melebihi saldo collateral akun pada token tersebut, seluruh likuidasi revert; tidak ada utang atau saldo yang berubah, dan likuidator dapat mencoba jumlah yang lebih kecil.
- Hanya `DSCEngine` yang boleh mencetak atau membakar DSC. Saat deployment, ownership token dipindahkan ke engine. `burnFrom` langsung pada token DSC dinonaktifkan agar supply dan utang tercatat hanya berubah melalui jalur engine.
- Lihat konstanta dan implementasi yang menjadi sumber kebenaran di [`src/DSCEngine.sol`](src/DSCEngine.sol) dan [`src/DecentralizedStableCoin.sol`](src/DecentralizedStableCoin.sol).

## Prasyarat dan konfigurasi

Pasang [Foundry](https://book.getfoundry.sh/getting-started/installation), lalu dari root repository:

```sh
forge --version
```

Dependensi Solidity dan remapping proyek tercatat di `lib/` dan [`foundry.toml`](foundry.toml). Source menggunakan Solidity `^0.8.18`; Foundry memilih compiler yang kompatibel.

Untuk deployment ke jaringan eksternal, siapkan endpoint RPC dan akun deployment dengan saldo native token untuk gas. File `.env` di root diabaikan Git; jangan commit private key atau kredensial. Contoh variabel yang dibutuhkan skrip:

```dotenv
SEPOLIA_RPC_URL="https://rpc-sepolia-anda"
PRIVATE_KEY="0xprivate-key-akun-deployer"
COLLATERAL_TOKEN="0xalamat-token-collateral"
COLLATERAL_PRICE_FEED="0xalamat-chainlink-feed-token-dalam-usd"
```

Muat variabel ke shell sebelum menjalankan perintah deployment agar interpolasi shell pada `--rpc-url` dan `--private-key` tersedia:

```sh
set -a
source .env
set +a
```

Gunakan akun khusus deployment dan endpoint RPC tepercaya. Jangan gunakan private key berisi aset bernilai pada mesin atau jaringan pengembangan. `PRIVATE_KEY` diperlukan sebagai argumen CLI; skrip mengambil `COLLATERAL_TOKEN` dan `COLLATERAL_PRICE_FEED` dari environment pada chain selain Anvil.

## Build dan test

```sh
forge build
forge test
forge fmt --check
```

Suite Foundry mencakup unit test untuk constructor, deposit, mint/burn, penebusan, health factor, oracle, dan likuidasi. Invariant test pada `test/invariant/DSCEngineInvariant.t.sol` memfuzz dua collateral, update harga, likuidasi, dan percobaan `burnFrom`; invariant mencakup konsistensi supply/utang, ledger collateral, dan health factor. Perubahan harga dapat membuat akun tidak sehat, jadi suite tidak mengharuskan semua akun selalu memiliki health factor minimal 1.

Untuk menjalankan suite tertentu:

```sh
forge test --match-path test/DSCEngine.t.sol
forge test --match-path test/invariant/DSCEngineInvariant.t.sol
```

Untuk memperbarui laporan hasil dan gas setelah seluruh test selesai:

```sh
forge test --gas-report > test-report.txt
```

Perintah tersebut mengganti [`test-report.txt`](test-report.txt) dengan keluaran lengkap Foundry; periksa status keluar perintah untuk memastikan test lulus.

## Deploy

Skrip deployment ada di [`script/DeployDSC.s.sol`](script/DeployDSC.s.sol). Pada chain ID Anvil `31337`, skrip membuat satu mock collateral `mWETH` dan price feed mock dengan harga awal `$2.000` dan 8 desimal. Pada chain lain, skrip membaca `COLLATERAL_TOKEN` dan `COLLATERAL_PRICE_FEED` dari environment. Skrip memvalidasi bahwa alamat bukan nol dan memiliki bytecode, lalu mendaftarkan **satu** jenis collateral. Constructor engine juga menolak token duplikat, alamat nol, dan alamat tanpa kontrak.

### Anvil lokal

Terminal pertama:

```sh
anvil
```

Terminal kedua, gunakan private key dev yang dicetak Anvil hanya untuk chain lokal:

```sh
forge script script/DeployDSC.s.sol:DeployDSC \
  --rpc-url http://127.0.0.1:8545 \
  --private-key "$PRIVATE_KEY" \
  --broadcast
```

Sebelum menjalankan perintah lokal tersebut, set `PRIVATE_KEY` ke salah satu private key dev yang dicetak Anvil pada terminal yang sama.

### Sepolia

Isi `.env` dengan RPC Sepolia, private key akun berisi Sepolia ETH, alamat token collateral yang ada di Sepolia, dan feed Chainlink USD untuk aset yang sama. Setelah variabel dimuat seperti di atas:

```sh
forge script script/DeployDSC.s.sol:DeployDSC \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast
```

Simpan alamat token DSC dan engine dari keluaran deployment/broadcast; skrip tidak memublikasikan alamat aplikasi ke layanan eksternal atau otomatis memverifikasi source di block explorer. Untuk jaringan selain Anvil, pemilihan alamat collateral/feed sepenuhnya tanggung jawab operator.

`script/HelperConfig.s.sol` berisi alamat feed ETH/USD dan BTC/USD untuk Sepolia/Mainnet serta mock config lokal, tetapi **tidak dipakai** oleh `DeployDSC.s.sol`. Jangan menganggap konfigurasi tersebut menentukan token/feed deployment saat ini. Skrip deployment generik tidak mengubah token/feed berdasarkan chain; operator bertanggung jawab memilih alamat yang sesuai. Verifikasi chain, token, feed, dan alamatnya secara independen sebelum deployment.

## Asumsi oracle

- Constructor engine membaca `decimals()` dari feed dan menolak feed dengan lebih dari 18 desimal; harga dikonversi ke precision 18 desimal sebelum valuasi.
- Setiap pembacaan harga memeriksa `answer > 0`, `roundId != 0`, `answeredInRound >= roundId`, `updatedAt != 0`, timestamp tidak di masa depan, dan usia data tidak lebih dari 3 jam. Harga tidak valid atau stale menyebabkan operasi yang memerlukan valuasi collateral revert.
- Validasi tersebut tidak membuktikan bahwa alamat adalah feed tepercaya, bahwa feed cocok dengan token collateral, atau bahwa denominasi feed adalah USD. Operator harus memeriksa pair, chain, alamat kontrak, dan kebijakan update/heartbeat feed sebelum deployment. Timeout 3 jam berlaku tetap untuk semua feed.
- Tidak ada batas kewajaran perubahan harga atau circuit breaker. Feed yang valid secara teknis tetapi salah atau dimanipulasi dapat menghasilkan valuasi yang salah.
- Mock feed lokal bukan harga pasar dan tidak sesuai untuk mengamankan aset produksi.

## Batasan protokol

- Protokol ini adalah implementasi minimal/eksperimental, bukan stablecoin produksi atau jaminan peg USD. Tidak ada biaya, governance, mekanisme stabilisasi pasar, circuit breaker, atau pengelolaan risiko oracle di luar validasi dasar di atas.
- Rasio likuidasi, ambang health factor, bonus, dan daftar collateral ditanam di kontrak saat deployment. Tidak ada fungsi administrasi untuk mengubah parameter atau menambah collateral setelah deploy.
- Skrip deployment saat ini mengonfigurasi hanya satu collateral, meskipun engine mendukung beberapa collateral melalui constructor. Invariant test menggunakan dua mock collateral dan tiga aktor; rentang aksi fuzz dibatasi dan revert pada aksi handler ditangkap. Hasil invariant bukan bukti keamanan untuk semua urutan aksi atau kondisi chain.
- Engine mengasumsikan token collateral ERC-20 biasa dengan transfer/transferFrom yang mengembalikan `bool`; token fee-on-transfer, rebasing, atau perilaku non-standar tidak didukung.
- Periksa dan uji kontrak, feed, likuidasi, dan pengaturan deployment secara independen sebelum menggunakan aset sungguhan.

## Laporan test

Laporan gas dan keluaran lengkap Foundry: [`test-report.txt`](test-report.txt).
