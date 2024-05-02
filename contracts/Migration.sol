// SPDX-License-Identifier: MIT
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

pragma solidity ^0.8.25;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./_testContracts/IUniswapV2Router02.sol";

/**
 * @dev Error used to indicate that a user attempting to migrate has no old Weirdo tokens.
 * This error is thrown in the migrate function if the user's balance of old Weirdo tokens is zero.
 */
    error NoWeirdoToMigrate();

/**
 * @dev Error used to indicate that an action is attempted while the migration is still open.
 * This error is thrown in functions that should only be executed when the migration has been closed,
 * such as extracting ETH from the liquidity pool or sending remaining Weirdo tokens to the treasury.
 */
    error OnlyWhenMigrationClosed();

/**
 * @dev Error used to indicate that an action is attempted after the migration has been closed.
 * This error is thrown in functions that require the migration to be open, such as migrating tokens.
 */
    error OnlyWhenMigrationOpened();

/**
 * @dev Error used to indicate that the required milestones for closing the migration have not been reached.
 * This could be due to not enough tokens being migrated or the specified time cap not being reached yet.
 * This error is thrown in the endMigration function if the conditions to end migration are not satisfied.
 */
    error MilestonesNotReached();

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
    bool private _migrateCapReached;

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

    event MigrateCapReached(uint256 startCountDown, uint256 endCountDown);


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
        _migrateCapReached = false; // migrateCap initialized as not reached
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
        // close migration automatically if migrateCap is reached and 42 hours passed
        if (_migrationOpened && _migrateCapReached) {
            if (block.timestamp > _timeCap) {
                _migrationOpened = false;
                emit MigrationClosed(_totalMigrated, _migrants, block.timestamp);
                return; // don't execute the rest of the migrate function when migration is closed
            }
        }
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
        // if migrate cap is reached launch 42 hours countdown
        if (_totalMigrated >= _migrateCap && !_migrateCapReached) {
            _timeCap = block.timestamp + 42 hours;
            _migrateCapReached = true; // set migrate cap reached to true
            emit MigrateCapReached(block.timestamp, _timeCap);
        }
        // atomic swap of old weirdo vs new weirdo
        require(IERC20(_oldWeirdo).transferFrom(msg.sender, address(this), oldBalance), "ERROR : cannot get old tokens");
        require(IERC20(_newWeirdo).transfer(msg.sender, newBalance), "ERROR : cannot send new tokens");
        emit WeirdoMigrated(msg.sender, oldBalance, newBalance);
        emit TotalMigrated(_migrants, _totalMigrated);
    }

    /**
    * @dev Ends the migration process manually.
    * Can only be called by the owner of the contract when the migration is open.
    * Ensures migration can only be ended if the total migrated tokens reach the migration cap
    * or the specified time cap has passed.
    * Sets the migration status to closed.
    * Emits a MigrationClosed event.
    *
    * Reverts if:
    * - the migration is already closed.
    * - time conditions are not met.
    */
    function endMigration() external onlyOwner {
        // check if migration still opened
        if (!_migrationOpened) {
            revert OnlyWhenMigrationOpened();
        }
        if (block.timestamp < _timeCap) {
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
    * @param amounts Array of amounts of old tokens held by recipients at the time of snapshot.
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
        uint256 exchangeRate = (_inflation * (1000 - _taxRate)) / 1000;
        uint256 length = recipients.length;
        for (uint256 i = 0; i < length; i++) {
            require(IERC20(_newWeirdo).transfer(recipients[i], amounts[i] * exchangeRate), "Transfer failed: Check balance and allowance");
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
    * @dev Transfers all collected old Weirdo tokens to the treasury as a fallback measure.
    * This function serves as a plan B in case the primary method of extracting ETH (via liquidity pool) fails.
    * It can only be executed by the owner and only after the migration has been closed.
    *
    * @notice Use this function only if the `extractEthFromLP` function fails to convert old tokens into ETH as expected.
    *
    * Reverts if:
    * - the migration is still open.
    * - the transfer of old Weirdo tokens to the treasury fails.
    */
    function sendOldWeirdoToTreasury() external onlyOwner {
        if (_migrationOpened) {
            revert OnlyWhenMigrationClosed();
        }
        uint256 collected = IERC20(_oldWeirdo).balanceOf(address(this));
        require(IERC20(_oldWeirdo).transfer(_treasury, collected), "Transfer to treasury failed");
    }

    /**
    * @dev Returns the address of the old Weirdo token contract.
    * @return The address of the old Weirdo token.
    */
    function getOldWeirdo() external view returns (address) {
        return _oldWeirdo;
    }

    /**
    * @dev Returns the address of the new Weirdo token contract.
    * @return The address of the new Weirdo token.
    */
    function getNewWeirdo() external view returns (address) {
        return _newWeirdo;
    }

    /**
    * @dev Returns status on migration cap
    * @return true if threshold of tokens has been migrated, false otherwise.
    */
    function isMigrateCapReached() external view returns (bool) {
        return _migrateCapReached;
    }

    /**
    * @dev Returns the address of the treasury.
    * @return The address of the treasury where funds and tokens are stored.
    */
    function getTreasury() external view returns (address) {
        return _treasury;
    }

    /**
    * @dev Returns the address of the Uniswap V2 router used for token swaps.
    * @return The address of the Uniswap V2 router.
    */
    function getUniV2Router() external view returns (address) {
        return _uniV2Router;
    }

    /**
    * @dev Returns the inflation rate used for converting old tokens to new tokens.
    * @return The inflation multiplier.
    */
    function getInflation() external view returns (uint256) {
        return _inflation;
    }

    /**
    * @dev Returns the total number of old tokens that have been migrated.
    * @return The total amount of migrated old tokens.
    */
    function getTotalMigrated() external view returns (uint256) {
        return _totalMigrated;
    }

    /**
    * @dev Returns the number of addresses that have participated in the migration.
    * @return The number of participants in the migration.
    */
    function getMigrants() external view returns (uint256) {
        return _migrants;
    }

    /**
    * @dev Returns the time cap of the migration, which is the timestamp after which migration can be halted by the owner.
    * @return The timestamp indicating the end of the migration period.
    */
    function getTimeCap() external view returns (uint256) {
        return _timeCap;
    }

    /**
    * @dev Returns the migration cap, which is the minimum amount of old tokens that should be migrated.
    * @return The migration cap.
    */
    function getMigrateCap() external view returns (uint256) {
        return _migrateCap;
    }

    /**
    * @dev Returns the tax rate applied to late migrations.
    * @return The tax rate as a percentage, expressed in parts per thousand.
    */
    function getTaxRate() external view returns (uint256) {
        return _taxRate;
    }

    /**
    * @dev Checks whether the migration is currently open.
    * @return True if the migration is open, false otherwise.
    */
    function isMigrationOpened() external view returns (bool) {
        return _migrationOpened;
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
