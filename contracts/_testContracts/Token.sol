// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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

contract Token is ERC20 {
    constructor(uint256 _initialSupply) ERC20("weirdo", "weirdo"){
        _mint(msg.sender, _initialSupply);
    }
}
