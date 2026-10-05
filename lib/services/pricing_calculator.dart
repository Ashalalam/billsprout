// =====================================================
// Pricing Calculator for Loose-Unit Sales
// =====================================================
// Handles per-unit price calculations, pricing tier resolution,
// and mixed quantity pricing (packs + loose units)

import '../models/product_model.dart';
import '../models/batch_model.dart';
import '../models/selling_unit_model.dart';

enum PricingTier {
  retail,      // MRP
  ptr,         // Price to Retailer
  wholesale,   // Wholesale price
  distributor, // 90% of wholesale
  loyalty,     // 95% of MRP (for loyalty customers)
}

class PricingCalculator {
  /// Calculate price per base unit from pack price
  /// Example: Strip MRP ₹90, 10 tablets per strip → ₹9 per tablet
  static double calculatePricePerUnit({
    required double packPrice,
    required int unitsPerPack,
  }) {
    if (unitsPerPack <= 0) return 0.0;
    return packPrice / unitsPerPack;
  }
  
  /// Get pack price based on pricing tier
  static double getPackPrice({
    required BatchModel batch,
    required PricingTier tier,
  }) {
    switch (tier) {
      case PricingTier.retail:
        return batch.mrp;
      case PricingTier.ptr:
        return batch.ptrPrice > 0 ? batch.ptrPrice : batch.mrp;
      case PricingTier.wholesale:
        return batch.wholesalePrice > 0 ? batch.wholesalePrice : batch.ptrPrice;
      case PricingTier.distributor:
        final wholesale = batch.wholesalePrice > 0 ? batch.wholesalePrice : batch.ptrPrice;
        return wholesale * 0.90; // 90% of wholesale
      case PricingTier.loyalty:
        return batch.mrp * 0.95; // 95% of MRP
    }
  }
  
  /// Get per-unit price based on pricing tier
  /// First checks if product has configured per-unit price
  /// Otherwise derives from pack price
  static double getUnitPrice({
    required ProductModel product,
    required BatchModel batch,
    required PricingTier tier,
  }) {
    // If product has explicit per-unit pricing, use it
    if (product.pricePerBaseUnit != null && product.pricePerBaseUnit! > 0) {
      // Apply tier adjustment to configured unit price
      return _applyTierMultiplier(product.pricePerBaseUnit!, tier);
    }
    
    // Otherwise derive from pack price
    final packPrice = getPackPrice(batch: batch, tier: tier);
    return calculatePricePerUnit(
      packPrice: packPrice,
      unitsPerPack: product.baseUnitsPerPack,
    );
  }
  
  /// Apply pricing tier multiplier to a base unit price
  static double _applyTierMultiplier(double basePrice, PricingTier tier) {
    switch (tier) {
      case PricingTier.retail:
        return basePrice;
      case PricingTier.ptr:
        return basePrice * 0.85; // 85% of retail
      case PricingTier.wholesale:
        return basePrice * 0.75; // 75% of retail
      case PricingTier.distributor:
        return basePrice * 0.68; // 68% of retail (90% of wholesale)
      case PricingTier.loyalty:
        return basePrice * 0.95; // 95% of retail
    }
  }
  
  /// Calculate total amount for a sale quantity
  static PricingResult calculateAmount({
    required ProductModel product,
    required BatchModel batch,
    required SaleQuantity quantity,
    required PricingTier tier,
    double discountPercent = 0.0,
    double discountAmount = 0.0,
  }) {
    // Get prices
    final packPrice = getPackPrice(batch: batch, tier: tier);
    final unitPrice = getUnitPrice(product: product, batch: batch, tier: tier);
    
    // Calculate pack amount (excluding free packs)
    final packAmount = quantity.packQuantity * packPrice;
    
    // Calculate loose unit amount (excluding free loose)
    final looseAmount = quantity.looseQuantity * unitPrice;
    
    // Gross total
    final grossTotal = packAmount + looseAmount;
    
    // Apply discounts
    double discountTotal = discountAmount;
    if (discountPercent > 0) {
      discountTotal += grossTotal * (discountPercent / 100);
    }
    
    final netAmount = grossTotal - discountTotal;
    
    return PricingResult(
      packPrice: packPrice,
      unitPrice: unitPrice,
      packAmount: packAmount,
      looseAmount: looseAmount,
      grossTotal: grossTotal,
      discountAmount: discountTotal,
      netAmount: netAmount,
      quantity: quantity,
    );
  }
  
  /// Validate that requested quantity can be fulfilled with available stock
  static StockValidationResult validateStock({
    required ProductModel product,
    required BatchModel batch,
    required SaleQuantity quantity,
  }) {
    final available = AvailableStock(
      packStock: batch.stockCount,
      looseUnits: batch.looseUnits,
      baseUnitsPerPack: product.baseUnitsPerPack,
    );
    
    // Calculate required units
    final requiredPackUnits = quantity.packQuantity + quantity.freePackQuantity;
    final requiredLooseUnits = quantity.looseQuantity + quantity.freeLooseQuantity;
    
    // Check pack stock
    if (requiredPackUnits > available.packStock) {
      return StockValidationResult(
        isValid: false,
        errorMessage: 'Insufficient pack stock. Available: ${available.packStock}, Required: $requiredPackUnits',
      );
    }
    
    // Check loose stock (may need to open packs)
    final availableLoose = available.looseUnits;
    final packsToOpen = available.packsToOpen(requiredLooseUnits);
    final totalPacksNeeded = requiredPackUnits + packsToOpen;
    
    if (totalPacksNeeded > available.packStock) {
      return StockValidationResult(
        isValid: false,
        errorMessage: 'Insufficient stock for loose units. Would need to open $packsToOpen packs but only ${available.packStock - requiredPackUnits} available',
      );
    }
    
    return StockValidationResult(
      isValid: true,
      packsToOpen: packsToOpen,
      availableStock: available,
    );
  }
  
  /// Calculate suggested retail price per unit with margin
  /// Used when configuring new products
  static double suggestRetailPricePerUnit({
    required double purchasePrice,
    required int unitsPerPack,
    double marginPercent = 25.0, // Default 25% margin
  }) {
    if (unitsPerPack <= 0) return 0.0;
    
    final costPerUnit = purchasePrice / unitsPerPack;
    final suggestedPrice = costPerUnit * (1 + marginPercent / 100);
    
    // Round to nearest paisa (0.01)
    return (suggestedPrice * 100).round() / 100;
  }
  
  /// Round price to nearest rupee (for cash transactions)
  static double roundToNearestRupee(double amount) {
    return amount.roundToDouble();
  }
  
  /// Round price to 2 decimal places (paisa)
  static double roundToPaisa(double amount) {
    return (amount * 100).round() / 100;
  }
}

/// Result of pricing calculation
class PricingResult {
  final double packPrice;      // Price per pack
  final double unitPrice;      // Price per loose unit
  final double packAmount;     // Amount from pack sales
  final double looseAmount;    // Amount from loose unit sales
  final double grossTotal;     // Total before discount
  final double discountAmount; // Applied discount
  final double netAmount;      // Total after discount
  final SaleQuantity quantity; // Sale quantity breakdown
  
  const PricingResult({
    required this.packPrice,
    required this.unitPrice,
    required this.packAmount,
    required this.looseAmount,
    required this.grossTotal,
    required this.discountAmount,
    required this.netAmount,
    required this.quantity,
  });
  
  /// Display text for invoice line
  /// Example: "2 Strips @ ₹90 + 5 Tablets @ ₹9 = ₹225"
  String get displayText {
    final parts = <String>[];
    
    if (quantity.packQuantity > 0) {
      parts.add('${quantity.packQuantity} ${quantity.sellingUnit.pluralLabel} @ ₹${packPrice.toStringAsFixed(2)}');
    }
    
    if (quantity.looseQuantity > 0) {
      final looseUnit = _getLooseUnit(quantity.sellingUnit);
      parts.add('${quantity.looseQuantity} ${looseUnit.pluralLabel} @ ₹${unitPrice.toStringAsFixed(2)}');
    }
    
    final breakdownText = parts.join(' + ');
    
    if (discountAmount > 0) {
      return '$breakdownText = ₹${grossTotal.toStringAsFixed(2)} - ₹${discountAmount.toStringAsFixed(2)} = ₹${netAmount.toStringAsFixed(2)}';
    }
    
    return '$breakdownText = ₹${netAmount.toStringAsFixed(2)}';
  }
  
  SellingUnit _getLooseUnit(SellingUnit packUnit) {
    switch (packUnit) {
      case SellingUnit.strip:
      case SellingUnit.tablet:
        return SellingUnit.tablet;
      case SellingUnit.capsule:
        return SellingUnit.capsule;
      case SellingUnit.bottle:
      case SellingUnit.ml:
        return SellingUnit.ml;
      case SellingUnit.tube:
      case SellingUnit.gm:
        return SellingUnit.gm;
      default:
        return SellingUnit.unit;
    }
  }
}

/// Result of stock validation
class StockValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int packsToOpen;
  final AvailableStock? availableStock;
  
  const StockValidationResult({
    required this.isValid,
    this.errorMessage,
    this.packsToOpen = 0,
    this.availableStock,
  });
}
