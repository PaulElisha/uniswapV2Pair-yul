// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract CrowdFundingSolidity {
    uint256 id;

    struct Campaign {
        address owner;
        uint256 targetAmount;
        uint256 endTimestamp;
        uint256 amountRaised;
    }

    mapping(uint256 => Campaign) campaigns;
    mapping(address => uint256) donations;

    function createCampaign(uint256 target, uint256 duration) public {
        campaigns[id] = Campaign({
            owner: msg.sender,
            targetAmount: target,
            endTimestamp: block.timestamp + duration,
            amountRaised: 0
        });

        id++;
    }

    function contribute(uint256 campaignId) public payable {
        require(msg.value > 0);

        require(block.timestamp < campaigns[campaignId].endTimestamp);

        donations[msg.sender] += msg.value;

        campaigns[campaignId].amountRaised += msg.value;
    }

    function withdrawOwner(uint256 campaignId) public {
        Campaign memory campaign = campaigns[campaignId];
        require(msg.sender == campaign.owner);

        require(campaign.amountRaised > campaign. targetAmount);

        campaigns[campaignId].amountRaised = 0;

        (bool os, ) = payable(msg.sender).call{value: campaign.amountRaised}("");
        require(os);
    }

    function withdrawDonor(uint256 campaignId) public {
        require(donations[msg.sender] > 0);

        Campaign memory campaign = campaigns[campaignId];

        require(block.timestamp > campaign.endTimestamp);
        require(campaign.targetAmount < campaign.amountRaised);

        uint256 amountDonated = donations[msg.sender];
        donations[msg.sender] = 0;

        (bool os, ) = payable(msg.sender).call{value: amountDonated}("");
        require(os);
    }
}