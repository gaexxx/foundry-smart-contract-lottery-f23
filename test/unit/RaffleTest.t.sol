// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Test, console} from "lib/forge-std/src/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    event EnteredRaffle(address indexed player);
    // event RequestedRaffleWinner(uint256 indexed requestId);
    event PickedWinner(address indexed winner);
    event RandomWordsFulfilled(uint256 indexed requestId, uint256 outputSeed, uint96 payment, bool success);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkToken;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit, linkToken,) =
            helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    modifier funded() {
        raffle.enterRaffle{value: entranceFee}();
        _;
    }

    modifier timePassed() {
        vm.warp(block.timestamp + interval + 1);
        // vm.roll(block.number + 1);
        _;
    }

    modifier skipTestnetTest() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    receive() external payable {}

    ////////////enter raffle()

    function testRaffleInitialzesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsIfNotEnoughEthAreSent() public {
        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
        raffle.enterRaffle{value: 1}();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public funded {
        assert(raffle.getPlayer(0) == address(this));
    }

    function testEmitsEventOnEntrance() public {
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(address(this));
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public funded timePassed {
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testTheSamePlayerCantEnterTwice() public funded {
        vm.expectRevert(Raffle.Raffle_AlreadyEntered.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testMoretThanOnePlayerCanEnter() public funded {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //////////// checkUpkeep()

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public timePassed {
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(block.timestamp > interval);
    }

    function testCheckUpkeepRetursFalseIfRaffleNotOpen() public funded timePassed {
        raffle.performUpkeep("");
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
        assert(raffle.getPlayer(0) == address(this));
        assert(block.timestamp > interval);
    }

    function testCheckUpkeepReturnsFalseIfEnoughtTimeHasntPassed() public funded {
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(raffle.getPlayer(0) == address(this));
        // assert(block.timestamp < interval);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public funded timePassed {
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    ////////////// performUpKeep

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public funded timePassed {
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // with custom error with parameters the error needs to be encodedWithSelector
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle_UpkeepNotNeeded.selector, 0, 0, 0, 0));
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public funded timePassed {
        // vm.expectEmit(true, false, false, false, address(raffle));
        // if (block.chainid == 31337) {
        //     emit RequestedRaffleWinner(1);
        //     raffle.performUpkeep("");
        // }
        // if (block.chainid == 11155111) {
        //     emit RequestedRaffleWinner(1083);
        //     raffle.performUpkeep("");
        // }

        // way to show an event of a function e get a data
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // performUpkeep è override e ha molti eventi
        bytes32 requestId = entries[1].topics[1];
        assert(uint256(requestId) > 0);
    }

    function testFulfillRandomWordsCantBeCalledWithoutPerformUpkeep(uint256 randomRequestId)
        public
        skipTestnetTest
        funded
        timePassed
    {
        vm.expectRevert();
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep() public skipTestnetTest funded timePassed {
        raffle.performUpkeep("");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(1, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendMoney() public skipTestnetTest funded timePassed {
        uint256 afterFundedRaffleBalance = address(raffle).balance;
        uint256 initialBalanceOfThis = address(this).balance;
        raffle.performUpkeep("");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(1, address(raffle));
        uint256 finalBalanceOfThis = address(this).balance;
        address recentWinner = raffle.getRecentWinner();
        assert(recentWinner == address(this));
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(raffle.getLastTimestamp() == block.timestamp);
        assert(afterFundedRaffleBalance == (finalBalanceOfThis - initialBalanceOfThis));
        assert(address(raffle).balance == 0);
        assert(raffle.getLengthOfPlayers() == 0);
        assert(raffle.enteredAddress(msg.sender) == false);
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendMoney2() public skipTestnetTest funded timePassed {
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        // to get the requestId
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // performUpkeep è override e ha molti eventi
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimestamp = raffle.getLastTimestamp();

        vm.recordLogs();
        //pretend to be chainlink vrf to get the random number and pick winner

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        Vm.Log[] memory entries2 = vm.getRecordedLogs();
        // performUpkeep è override e ha molti eventi
        bytes32 winner = entries2[0].topics[1];
        assert(uint256(winner) == uint160(raffle.getRecentWinner()));

        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(previousTimestamp < raffle.getLastTimestamp());
        assert(raffle.getRecentWinner().balance == (STARTING_USER_BALANCE - entranceFee) + prize);
    }

    function testTheSamePlayerCanEnterAfterRaffleFinish() public skipTestnetTest funded timePassed {
        raffle.performUpkeep("");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(1, address(raffle));
        raffle.enterRaffle{value: entranceFee}();
    }

    function testGetEntranceFee() external view {
        assert(raffle.getEntranceFee() == 0.01 ether);
    }
}
