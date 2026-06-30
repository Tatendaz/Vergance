import Foundation

/// A normalized rectangle in screen space (origin top-left, each axis in [0, 1]).
public struct Rect: Sendable, Equatable, Codable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    public func contains(_ p: ScreenPoint) -> Bool {
        p.x >= x && p.x <= x + w && p.y >= y && p.y <= y + h
    }
}

/// A named, hit-testable element on the active surface.
public struct Element: Sendable, Equatable, Codable {
    public var id: String
    public var role: String?
    public var label: String?
    public var rect: Rect

    public init(id: String, role: String? = nil, label: String? = nil, rect: Rect) {
        self.id = id
        self.role = role
        self.label = label
        self.rect = rect
    }
}

/// The element tree gaze is resolved against. The first staged surface (Vergance's own
/// canvas) owns this map directly; later surfaces (browser DOM, Accessibility API) build
/// an equivalent map from their respective trees.
public struct ElementMap: Sendable, Equatable, Codable {
    public var elements: [Element]

    public init(elements: [Element] = []) {
        self.elements = elements
    }

    /// Resolve a gaze point to an element. Topmost (last) match wins.
    public func hitTest(_ p: ScreenPoint) -> Element? {
        elements.last { $0.rect.contains(p) }
    }

    /// Build a ``GazeTarget`` for a resolved element, carrying dwell/overlap metadata.
    public func target(
        for element: Element,
        dwellMs: Double? = nil,
        overlap: String? = nil,
        confidence: Double? = nil
    ) -> GazeTarget {
        GazeTarget(
            id: element.id,
            role: element.role,
            label: element.label,
            dwellMs: dwellMs,
            overlap: overlap,
            confidence: confidence
        )
    }

    /// Resolve a gaze point to a ``GazeTarget`` on this surface: the containing element's
    /// `id`/`role`/`label` when one is hit (topmost-match-wins via ``hitTest(_:)``), else a
    /// geometric region-id fallback so a candidate target is never dropped. This is the single
    /// resolution path shared by ``UtteranceFuser`` and ``FixationEvent``.
    public func resolve(
        _ p: ScreenPoint,
        dwellMs: Double? = nil,
        overlap: String? = nil,
        confidence: Double? = nil
    ) -> GazeTarget {
        if let element = hitTest(p) {
            return target(for: element, dwellMs: dwellMs, overlap: overlap, confidence: confidence)
        }
        return GazeTarget(
            id: UtteranceFuser.regionID(for: p),
            role: "region",
            dwellMs: dwellMs,
            overlap: overlap,
            confidence: confidence
        )
    }
}
