import { BigInt, Bytes } from "@graphprotocol/graph-ts"
import {
  LiquidityAdded,
  ResourcesSwapped
} from "../generated/ResourceMarketplace/ResourceMarketplace"
import {
  LiquidityProvider,
  SwapEvent,
  LiquidityEvent
} from "../generated/schema"

export function handleLiquidityAdded(event: LiquidityAdded): void {
  let providerId = event.params.liquidityProvider.toHexString()
  let provider = LiquidityProvider.load(providerId)
  if (provider == null) {
    provider = new LiquidityProvider(providerId)
    provider.address = event.params.liquidityProvider
    provider.totalLiquidityAdded = BigInt.fromI32(0)
    provider.totalLiquidityRemoved = BigInt.fromI32(0)
  }
  provider.totalLiquidityAdded = provider.totalLiquidityAdded.plus(event.params.liquidityTokensMinted)
  provider.save()

  let liquidityEventId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  let liquidityEvent = new LiquidityEvent(liquidityEventId)
  liquidityEvent.liquidityProvider = event.params.liquidityProvider
  liquidityEvent.firstResourceAmount = event.params.firstResourceAmount
  liquidityEvent.secondResourceAmount = event.params.secondResourceAmount
  liquidityEvent.liquidityTokens = event.params.liquidityTokensMinted
  liquidityEvent.blockTimestamp = event.block.timestamp
  liquidityEvent.isAddition = true
  liquidityEvent.save()
}

export function handleResourcesSwapped(event: ResourcesSwapped): void {
  let swapId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  let swap = new SwapEvent(swapId)
  swap.swapInitiator = event.params.swapInitiator
  swap.inputResourceId = event.params.inputResourceId
  swap.outputResourceId = event.params.outputResourceId
  swap.inputAmount = event.params.inputResourceAmount
  swap.outputAmount = event.params.outputResourceAmount
  swap.blockTimestamp = event.block.timestamp
  swap.save()
}