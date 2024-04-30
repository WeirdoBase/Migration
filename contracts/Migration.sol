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

    address private _oldWeirdo;
    address private _newWeirdo;
    address private _treasury;
    address private _uniV2Router;
    uint256 private _inflation;
    uint256 private _totalMigrated;
    uint256 private _migrants;
    uint256 private _timeCap;
    uint256 private _migrateCap;
    uint256 private _taxRate;
    bool private _migrationOpened;


    event MigrationInitialized(
        address oldWeirdo,
        address newWeirdo,
        uint256 inflation,
        uint256 taxRate,
        uint256 timeCap,
        uint256 migrateCap,
        address treasury
    );
    event WeirdoMigrated(address migrant, uint256 oldBalance, uint256 newBalance);
    event TotalMigrated(uint256 migrants, uint256 totalMigrated);
    event MigrationClosed(uint256 totalMigrated, uint256 migrants, uint256 timestamp);
    event ETHExtracted(uint256 balanceETH);

    constructor (
        address oldWeirdo,
        address newWeirdo,
        uint256 inflation,
        uint256 taxRate,
        uint256 minDays,
        uint256 migrateCap,
        address treasury,
        address uniV2Router
    ) Ownable(treasury){
        _oldWeirdo = oldWeirdo;
        _newWeirdo = newWeirdo;
        _inflation = inflation;
        _totalMigrated = 0;
        _migrants = 0;
        _taxRate = taxRate;
        _timeCap = block.timestamp + (minDays * 1 days);
        _migrateCap = migrateCap * (IERC20(_oldWeirdo).totalSupply()/100);
        _migrationOpened = true;
        _treasury = treasury;
        _uniV2Router = uniV2Router;
        emit MigrationInitialized(oldWeirdo, newWeirdo, inflation, taxRate, _timeCap, _migrateCap, treasury);
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
