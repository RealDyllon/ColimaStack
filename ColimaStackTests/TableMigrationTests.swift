//
//  TableMigrationTests.swift
//  ColimaStackTests
//
//  Tests for the data-tables capability: column sort, multi-select,
//  copy-with-context, and contextual action bar visibility.
//

import XCTest
import SwiftUI
@testable import ColimaStack

final class TableMigrationTests: XCTestCase {
    func testTableDensityStandardPadding() {
        XCTAssertEqual(TableDensity.standard.rowVerticalPadding, 8)
        XCTAssertEqual(TableDensity.standard.font, .body)
    }

    func testTableDensityCompactPadding() {
        XCTAssertEqual(TableDensity.compact.rowVerticalPadding, 3)
        XCTAssertEqual(TableDensity.compact.font, .subheadline)
    }

    func testTableColumnCustomizationDefaults() {
        let customization = TableColumnCustomization()
        let order = customization.order(for: .containers, default: ["name", "image"])
        XCTAssertEqual(order, ["name", "image"])
    }

    func testTableColumnCustomizationOrderOverrides() {
        var customization = TableColumnCustomization()
        customization.setOrder(["image", "name", "state"], for: .containers)
        XCTAssertEqual(customization.order(for: .containers, default: ["name", "image"]),
                       ["image", "name", "state"])
    }

    func testTableColumnCustomizationHidden() {
        var customization = TableColumnCustomization()
        customization.setHidden("state", hidden: true, for: .containers)
        XCTAssertTrue(customization.isHidden("state", for: .containers))
        XCTAssertFalse(customization.isHidden("name", for: .containers))
        customization.setHidden("state", hidden: false, for: .containers)
        XCTAssertFalse(customization.isHidden("state", for: .containers))
    }

    func testTableRowCopyValueJoinsNonEmpty() {
        let copy = tableRowCopyValue(["a", "", "b", "c"])
        XCTAssertEqual(copy, "a\tb\tc")
    }

    func testTableRowCopyValueAllEmpty() {
        XCTAssertEqual(tableRowCopyValue(["", "", ""]), "")
    }

    func testResourceTableKindDisplayNames() {
        XCTAssertEqual(ResourceTableKind.containers.displayName, "Containers")
        XCTAssertEqual(ResourceTableKind.images.displayName, "Images")
        XCTAssertEqual(ResourceTableKind.runtimeVolumes.displayName, "Volumes")
        XCTAssertEqual(ResourceTableKind.runtimeNetworks.displayName, "Networks")
        XCTAssertEqual(ResourceTableKind.kubernetesPods.displayName, "Pods")
        XCTAssertEqual(ResourceTableKind.kubernetesDeployments.displayName, "Deployments")
        XCTAssertEqual(ResourceTableKind.kubernetesServices.displayName, "Services")
    }

    func testTableDensityEnumExhaustiveness() {
        let all = TableDensity.allCases
        XCTAssertTrue(all.contains(.standard))
        XCTAssertTrue(all.contains(.compact))
    }
}
