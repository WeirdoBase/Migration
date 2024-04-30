// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./_testContracts/IUniswapV2Router02.sol";

error NoWeirdoToMigrate();
error OnlyWhenMigrationClosed();
error OnlyWhenMigrationOpened();
error MilestonesNotReached();

/*

                              _            _          _
             __      __  ___ (_) _ __   __| |  ___   | |__    __ _  ___   ___
             \ \ /\ / / / _ \| || '__| / _` | / _ \  | '_ \  / _` |/ __| / _ \
              \ V  V / |  __/| || |   | (_| || (_) | | |_) || (_| |\__ \|  __/
               \_/\_/   \___||_||_|    \__,_| \___/  |_.__/  \__,_||___/ \___|


                                       .'``````^``'.
                                  ."i)t\\||||||||\\tt|-;`.
                               ';{/||||||||||||||||||||||t?^
                             ^{t||||||||||||||||||||||||||||fl,,,,,,l!!;'
                           `)\||||/|\tft//\\||||||||||||/tf/t/c$$$$$$$$u1){I^`
                       '^l/$#|||\\//[~-+{+)f\|||||||||\f/}}}/trM$$$$$$$@t~;,'
               ^!tn*8@$$$$$$z||f\;'.'^`   ..,(||||||\t~`.    .`+@$$$$$$x+".
           ',I_xuB$$$$$$$$$%|||t. -@$$$W'   .'j|||||/l.   >#8j" |$$&vj/~;`.
          .'`,i/$$$$$$$$$$$n//|1. :n@$&\.   .,t|\|||||.   ]B$@>'I`.
          .````^{$$$$$$$$$$r|||/i` .. .    `-t|||||||||,`''^``i,
               """"""";1M$$u|||||\\}++->][/|||\||||||||||\ttt/f"
                         'u\||||||||||||||||\||||||||||||||||||]
                          {|||||||\|fnvczzz*cvunuxxxnuunnuunnr/t,
                          `r||||\/vWM#########################W#*,
                           `f||\tnW#####WuvWWMMMMMMMMMWWWWWW####W&
                            "j|/\/MM###M[>W##MMMMMMMMMM##########&'
                            `n|||||rzW#&`c####################MWzn
                            /v|||||||\ru/-8MMMWMMMMMMMWMMM#zvxt|/:
                           _rc||||||||||||||||\\\\\\\\\|||||||||j.
                         .}f|rf||||||||||||||t|ft||/|/\||||||||f,
                       .Ij\|||rf\|||||||||||||\t/\||/\\|||||||ti
                    .,[r\|||||||ffjff/||||||||||||||||||||||\/^
              .'`"{/j\|||||||||||||||/jffjft||||\/fxtj/\ff(~"
          `,ix|:  ."}t\||||||||||||||||||||/tc``````'''..

*/

contract Migration is Ownable {

    address private _oldWeirdo; // Address of the old Weirdo token contract.
    address private _newWeirdo; // Address of the new Weirdo token contract.
    address private _treasury; // Address of the treasury where funds and tokens are stored.
    address private _uniV2Router; // Address of the Uniswap V2 router used for swapping tokens.
    uint256 private _inflation; // Multiplier to calculate new token amount based on old tokens.
    uint256 private _totalMigrated; // Total amount of old tokens that have been migrated.
    uint256 private _migrants; // Number of addresses that have participated in the migration.
    uint256 private _timeCap; // Timestamp after which migration can be closed by the owner.
    uint256 private _migrateCap; // Amount of old tokens that have to be migrated to close migration.
    uint256 private _taxRate; // Tax rate applied to the migration of late participants.
    bool private _migrationOpened; // Flag to indicate whether migration is open or closed.

    // Emitted when the migration process is initialized.
    event MigrationInitialized(
        address oldWeirdo,     // Address of the old Weirdo token contract.
        address newWeirdo,     // Address of the new Weirdo token contract.
        uint256 inflation,     // Inflation rate applied to calculate new token amounts.
        uint256 taxRate,       // Tax rate for calculating deductions on late migrations.
        uint256 timeCap,       // Time limit until which migration can be closed.
        uint256 migrateCap,    // Minimum amount of old tokens to migrate before closing migration.
        address treasury       // Address of the treasury for storing extracted ETH and other funds.
    );

    // Emitted when a migrant successfully migrates their old tokens to new tokens.
    event WeirdoMigrated(
        address migrant,       // Address of the migrant.
        uint256 oldBalance,    // Amount of old tokens migrated.
        uint256 newBalance     // Amount of new tokens received post-migration.
    );

    // Emitted to report the overall progress of the migration.
    event TotalMigrated(
        uint256 migrants,      // Total number of participants in the migration.
        uint256 totalMigrated  // Total amount of old tokens migrated.
    );

    // Emitted when the migration is officially closed.
    event MigrationClosed(
        uint256 totalMigrated, // Total amount of old tokens migrated by the closure.
        uint256 migrants,      // Total number of migrants by the closure.
        uint256 timestamp      // Timestamp when the migration was closed.
    );

    // Emitted after successfully extracting ETH from the old liquidity pool.
    event ETHExtracted(
        uint256 balanceETH     // Amount of ETH extracted and transferred to the treasury.
    );


    /**
    * @dev Initializes the migration contract with the necessary parameters and sets the initial state.
    * The constructor sets up the old and new Weirdo token addresses, the inflation rate for token conversion,
    * the tax rate for late migrations, and other essential migration parameters.
    * It also initializes the time and cap for the migration and sets the contract's ownership to the treasury.
    *
    * @param oldWeirdo Address of the old Weirdo token contract.
    * @param newWeirdo Address of the new Weirdo token contract.
    * @param inflation Multiplier used to convert old tokens to new tokens.
    * @param taxRate The percentage (expressed as parts per thousand) that will be deducted as a tax from late migrations.
    * @param minDays Minimum number of days the migration will be open.
    * @param migrateCap Cap on the percentage of total old tokens that should be migrated, expressed as parts per hundred.
    * @param treasury Address of the treasury to which leftover tokens and extracted ETH will be sent.
    * @param uniV2Router Address of the Uniswap V2 router used for swapping tokens for ETH.
    *
    * Emits a MigrationInitialized event with initialization parameters.
    */
    constructor (
        address oldWeirdo,
        address newWeirdo,
        uint256 inflation,
        uint256 taxRate,
        uint256 minDays,
        uint256 migrateCap,
        address treasury,
        address uniV2Router
    ) Ownable(treasury) {
        _oldWeirdo = oldWeirdo;  // Set the address of the old Weirdo token contract.
        _newWeirdo = newWeirdo;  // Set the address of the new Weirdo token contract.
        _inflation = inflation;  // Set the inflation rate for converting old to new tokens.
        _totalMigrated = 0;      // Initialize the counter for total migrated tokens.
        _migrants = 0;           // Initialize the counter for the number of migrants.
        _taxRate = taxRate;      // Set the tax rate for calculating taxes on late migrations.
        _timeCap = block.timestamp + (minDays * 1 days);  // Set the deadline for the migration based on the current time and minDays.
        _migrateCap = migrateCap * (IERC20(_oldWeirdo).totalSupply() / 100);  // Calculate the cap for migrated tokens as a percentage of total supply.
        _migrationOpened = true;  // Flag the migration as open.
        _treasury = treasury;     // Set the treasury address.
        _uniV2Router = uniV2Router;  // Set the Uniswap V2 router address.
        emit MigrationInitialized(oldWeirdo, newWeirdo, inflation, taxRate, _timeCap, _migrateCap, treasury);  // Emit an event indicating that the migration has been initialized.
    }


    /**
    * @dev Migrates a user's old Weirdo tokens to new Weirdo tokens based on a predefined inflation rate.
    * This function can only be called when the migration is open.
    * Requires that the user has old Weirdo tokens to migrate.
    * Transfers old tokens from the user to the contract, and new tokens from the contract to the user.
    * Increments total migrated tokens and the count of migrants.
    * Emits WeirdoMigrated and TotalMigrated events.
    *
    * Reverts if:
    * - the migration is closed.
    * - the user has no old Weirdo tokens.
    * - the token transfers fail.
    */
    function migrate() external {
        // check if migration still opened
        if (!_migrationOpened) {
            revert OnlyWhenMigrationOpened();
        }
        uint256 oldBalance = IERC20(_oldWeirdo).balanceOf(msg.sender);
        // check user has weirdo to migrate
        if (oldBalance == 0) {
            revert NoWeirdoToMigrate();
        }
        // calculate the new balance following weirdo inflation
        uint256 newBalance = oldBalance * _inflation;
        // incrementing migration counters
        _totalMigrated += oldBalance;
        _migrants++;
        // atomic swap of old weirdo vs new weirdo
        require(IERC20(_oldWeirdo).transferFrom(msg.sender, address(this), oldBalance), "ERROR : cannot get old tokens");
        require(IERC20(_newWeirdo).transfer(msg.sender, newBalance), "ERROR : cannot send new tokens");
        emit WeirdoMigrated(msg.sender, oldBalance, newBalance);
        emit TotalMigrated(_migrants, _totalMigrated);
    }

    /**
    * @dev Ends the migration process.
    * Can only be called by the owner of the contract when the migration is open.
    * Ensures migration can only be ended if the total migrated tokens reach the migration cap
    * or the specified time cap has passed.
    * Sets the migration status to closed.
    * Emits a MigrationClosed event.
    *
    * Reverts if:
    * - the migration is already closed.
    * - neither the migration cap nor the time cap conditions are met.
    */
    function endMigration() external onlyOwner {
        // check if migration still opened
        if (!_migrationOpened) {
            revert OnlyWhenMigrationOpened();
        }
        if (_totalMigrated < _migrateCap && _timeCap < block.timestamp) {
            revert MilestonesNotReached();
        }
        _migrationOpened = false;
        emit MigrationClosed(_totalMigrated, _migrants, block.timestamp);
    }

    /**
    * @dev Swaps collected old Weirdo tokens for ETH and transfers the ETH to the treasury.
    * Reverts if the migration is still open.
    * Emits an ETHExtracted event upon completion.
    */
    function extractEthFromLP() external onlyOwner {
        // Ensure the migration is closed before allowing extraction
        if (_migrationOpened) {
            revert OnlyWhenMigrationClosed();
        }

        // Use the actual balance of the old tokens in this contract to handle any direct transfers
        uint256 weirdoCollected = IERC20(_oldWeirdo).balanceOf(address(this));

        // Swap the old Weirdo tokens for ETH
        _swapWeirdoForEth(weirdoCollected);

        // Retrieve the new balance of ETH in this contract post-swap
        uint256 ethCollected = address(this).balance;

        // Transfer the collected ETH to the treasury address
        (bool success, ) = _treasury.call{value: ethCollected}("");
        require(success, "Failed to send ETH to the treasury");

        // Emit the event with the amount of ETH transferred
        emit ETHExtracted(ethCollected);
    }

    /**
    * @dev Distributes new tokens to late migrants with a tax penalty.
    * The function deducts a tax from each airdrop amount based on a predefined tax rate.
    * @param recipients Array of addresses of the recipients.
    * @param amounts Array of amounts of new tokens to be distributed to each recipient.
    * Reverts if the migration is still open.
    * Reverts if token transfer fails due to insufficient balance or other reasons.
    * Requirements:
    * - Only the contract owner can call this function.
    * - Migration must be closed.
    */
    function lateMigrantDrop(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        if (_migrationOpened) {
            revert OnlyWhenMigrationClosed();
        }
        uint256 length = recipients.length;
        for (uint256 i = 0; i < length; i++) {
            require(IERC20(_newWeirdo).transfer(recipients[i], amounts[i] - tax(amounts[i])), "Transfer failed: Check balance and allowance");
        }
    }

    /**
    * @dev Transfers all remaining new Weirdo tokens held by this contract to the treasury.
    * This function can only be executed by the owner and only after the migration has been officially closed.
    * It is intended to handle the final transfer of any leftover new Weirdo tokens to the treasury,
    * which may include taxed tokens from late migrations or any tokens designated for community treasury allocation.
    *
    * Reverts if:
    * - the migration is still open.
    *
    * Emits a Transfer event from the ERC20 token contract.
    */
    function sendWeirdoToTreasury() external onlyOwner {
        if (_migrationOpened) {
            revert OnlyWhenMigrationClosed();
        }
        uint256 stash = IERC20(_newWeirdo).balanceOf(address(this));
        require(IERC20(_newWeirdo).transfer(_treasury, stash), "Transfer to treasury failed");
    }

    /**
    * @dev Calculates the tax to be deducted from an airdrop amount.
    * @param amount The original airdrop amount from which the tax is to be calculated.
    * @return The calculated tax based on the `_taxRate`.
    */
    function tax(uint256 amount) internal view returns(uint256) {
        return (amount/1000) * _taxRate;
    }

    /**
     * @dev Used for swapping weirdo for ETH
     */
    function _swapWeirdoForEth(
        uint256 tokenAmount
    ) private {
        address[] memory path = new address[](2);
        path[0] = _oldWeirdo;
        path[1] = IUniswapV2Router02(_uniV2Router).WETH();
        IERC20(_oldWeirdo).approve(_uniV2Router, tokenAmount);

        IUniswapV2Router02(_uniV2Router).swapExactTokensForETH(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }
}
