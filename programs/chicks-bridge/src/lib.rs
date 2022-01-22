use anchor_lang::prelude::*;
use anchor_spl::token::{self};

pub mod instructions;

use crate::instructions::*;
declare_id!("5NUrGJvho3cBe3P2uL7SN4xxzhzuXbD8NY1snVKiX1Hj");

#[program]
pub mod chicks_bridge {
    use super::*;
    pub fn migrate(
        ctx: Context<Migrate>,
        amount: u64,
        target_chain_id: u8,
        target_address: [u8; 20]
    ) -> ProgramResult {
        msg!("Transfer token ({})", amount);
        msg!("Target chain id ({})", target_chain_id);
        msg!("Target address ({}{}{}{}{}{})", target_address[0], target_address[1], target_address[2], target_address[17], target_address[18], target_address[19]);
        token::transfer(
            ctx.accounts.into_transfer_to_receiver(),
            amount,
        )?;
        msg!("End");
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}
