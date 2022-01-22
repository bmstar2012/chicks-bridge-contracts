/* eslint-disable @typescript-eslint/ban-ts-comment,import/extensions,import/no-unresolved */
import * as anchor from '@project-serum/anchor';
import { Address, Program } from '@project-serum/anchor';
import {PublicKey, SystemProgram, Transaction} from '@solana/web3.js';
import { TOKEN_PROGRAM_ID, Token } from "@solana/spl-token";
import { assert } from "chai";
import * as BN from "bn.js"
// @ts-ignore
import { ChicksBridge } from '../target/types/chicks_bridge';

/* eslint-disable @typescript-eslint/no-explicit-any,no-console */
const ConsoleHelper = (...args: any[]) => {
  if (process.env.NODE_ENV === 'production') return;
  console.log(...args);
};

describe('chicks-bridge', () => {
  const provider = anchor.Provider.env();
  anchor.setProvider(provider);

  // @ts-ignore
  const program = anchor.workspace.ChickBridge as Program<ChicksBridge>;

  let mintA = null as unknown as Token;
  let mintB = null as unknown as Token;
  let aliceTokenAccountA: anchor.web3.PublicKey | null = null;
  let bobTokenAccountB = null;
  let serviceTokenAccountA: anchor.web3.PublicKey | null = null;

  const takerAmount = 100000;
  const initializerAmount = 50000;
  const sendAmount = 120;
  const payer = anchor.web3.Keypair.generate();
  const mintAuthority = anchor.web3.Keypair.generate();
  const aliceMainAccount = anchor.web3.Keypair.generate();
  const bobMainAccount = anchor.web3.Keypair.generate();
  const serviceMainAccount = anchor.web3.Keypair.generate();

  it("initialise", async () => {
    await provider.connection.confirmTransaction(
      await provider.connection.requestAirdrop(payer.publicKey, 10000000000), // 10 sol
      "confirmed"
    );

    await provider.send(
      (() => {
        const tx = new Transaction();
        tx.add(
          SystemProgram.transfer({
            fromPubkey: payer.publicKey,
            toPubkey: aliceMainAccount.publicKey,
            lamports: 1000000000,
          }),
          SystemProgram.transfer({
            fromPubkey: payer.publicKey,
            toPubkey: bobMainAccount.publicKey,
            lamports: 1000000000,
          })
        );
        return tx;
      })(),
      [payer]
    );

    mintA = await Token.createMint(
      provider.connection,
      payer,
      mintAuthority.publicKey,
      null,
      0,
      TOKEN_PROGRAM_ID
    );

    mintB = await Token.createMint(
      provider.connection,
      payer,
      mintAuthority.publicKey,
      null,
      0,
      TOKEN_PROGRAM_ID
    );

    aliceTokenAccountA = await mintA.createAccount(aliceMainAccount.publicKey);
    serviceTokenAccountA = await mintA.createAccount(serviceMainAccount.publicKey);
    bobTokenAccountB = await mintB.createAccount(bobMainAccount.publicKey);

    await mintA.mintTo(
      aliceTokenAccountA,
      mintAuthority.publicKey,
      [mintAuthority],
      initializerAmount
    );

    await mintB.mintTo(
      bobTokenAccountB,
      mintAuthority.publicKey,
      [mintAuthority],
      takerAmount
    );

    const aliceTokenAccountInfoA = await mintA.getAccountInfo(aliceTokenAccountA);
    const bobTokenAccountInfoB = await mintB.getAccountInfo(bobTokenAccountB);

    assert.ok(aliceTokenAccountInfoA.amount as unknown as number === initializerAmount);
    assert.ok(bobTokenAccountInfoB.amount as unknown as number === takerAmount);

    const accounts = await provider.connection.getParsedTokenAccountsByOwner(
      aliceMainAccount.publicKey,
      {
        mint: mintA.publicKey
      }
    )

    ConsoleHelper(`initialise -> alice :${aliceTokenAccountInfoA}`)
    ConsoleHelper(`initialise -> aliceTokenAccountA :${aliceTokenAccountA.toBase58()}`)

    if (accounts && accounts.value && Array.isArray(accounts.value)) {
      accounts.value.forEach((item) => {
        const {account, pubkey} = item;
        const amount1 = account.data.parsed.info.tokenAmount.amount;
        ConsoleHelper(`initialise -> account :${pubkey.toString()}`)
        ConsoleHelper(`initialise -> amount :${amount1}`)
      })
    }
  });

  it("transfer token", async () => {
    await program.rpc.migrate(
      new anchor.BN(sendAmount),
      1,
      Buffer.from(Uint8Array.of(...new BN(`c203c43Cc574688EDeb8F6E997AF11391aB2ed40`, 'hex').toArray("le", 20))),
      {
        accounts: {
          initializer: aliceMainAccount.publicKey,
          senderTokenAccount: aliceTokenAccountA as unknown as Address,
          receiverTokenAccount: serviceTokenAccountA as unknown as Address,
          tokenProgram: TOKEN_PROGRAM_ID,
        },
        signers: [aliceMainAccount],
      }
    );
    if (aliceTokenAccountA instanceof PublicKey) {
      const aliceTokenAccountInfoA = await mintA.getAccountInfo(aliceTokenAccountA);
      ConsoleHelper(`transfer token -> alice :${aliceTokenAccountInfoA}`)
    }
    if (serviceTokenAccountA instanceof PublicKey) {
      const serviceTokenAccountInfoA = await mintA.getAccountInfo(serviceTokenAccountA);
      ConsoleHelper(`transfer token -> service :${serviceTokenAccountInfoA}`)
    }
  });
});
