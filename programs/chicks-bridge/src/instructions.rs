use anchor_lang::prelude::*;
use anchor_spl::token::{TokenAccount, Transfer};

#[derive(Accounts)]
#[instruction(amount: u64)]
pub struct Migrate<'info> {
    #[account(mut, signer)]
    pub initializer: AccountInfo<'info>,
    #[account(
    mut,
    constraint = sender_token_account.amount >= amount
    )]
    pub sender_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub receiver_token_account: Account<'info, TokenAccount>,
    pub token_program: AccountInfo<'info>,
}

impl<'info> Migrate<'info> {
    pub fn into_transfer_to_receiver(&self) -> CpiContext<'_, '_, '_, 'info, Transfer<'info>> {
        let cpi_accounts = Transfer {
            from: self.sender_token_account.to_account_info().clone(),
            to: self.receiver_token_account.to_account_info().clone(),
            authority: self.initializer.clone(),
        };
        CpiContext::new(self.token_program.clone(), cpi_accounts)
    }
}
