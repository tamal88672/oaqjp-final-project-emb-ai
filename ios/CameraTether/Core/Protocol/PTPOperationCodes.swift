import Foundation

enum PTPOperationCode: UInt16 {
    case getDeviceInfo    = 0x1001
    case openSession      = 0x1002
    case closeSession     = 0x1003
    case getStorageIDs    = 0x1004
    case getStorageInfo   = 0x1005
    case getNumObjects    = 0x1006
    case getObjectHandles = 0x1007
    case getObjectInfo    = 0x1008
    case getObject        = 0x1009
    case getThumb         = 0x100A
    case deleteObject     = 0x100B
    case sendObjectInfo   = 0x100C
    case sendObject       = 0x100D
}

enum PTPEventCode: UInt16 {
    case cancelTransaction  = 0x4001
    case objectAdded        = 0x4002
    case objectRemoved      = 0x4003
    case storeAdded         = 0x4004
    case storeRemoved       = 0x4005
    case devicePropChanged  = 0x4006
    case objectInfoChanged  = 0x4007
    case deviceInfoChanged  = 0x4008
    case storeFull          = 0x400A
    case deviceReset        = 0x400B
    case storageInfoChanged = 0x400C
    case captureComplete    = 0x400D
    case unreported         = 0xFFFF
}

enum PTPResponseCode: UInt16 {
    case ok                      = 0x2001
    case generalError            = 0x2002
    case sessionNotOpen          = 0x2003
    case invalidTransactionID    = 0x2004
    case operationNotSupported   = 0x2005
    case parameterNotSupported   = 0x2006
    case incompleteTransfer      = 0x2007
    case invalidStorageID        = 0x2008
    case invalidObjectHandle     = 0x2009
    case devicePropNotSupported  = 0x200A
    case invalidObjectFormatCode = 0x200B
    case storageFull             = 0x200C
    case objectWriteProtected    = 0x200D
    case storeReadOnly           = 0x200E
    case accessDenied            = 0x200F
    case noThumbnailPresent      = 0x2010
    case selfTestFailed          = 0x2011
    case partialDeletion         = 0x2012
    case storeNotAvailable       = 0x2013
    case specificationByFormatUnsupported = 0x2014
    case noValidObjectInfo       = 0x2015
    case invalidCodeFormat       = 0x2016
    case unknownVendorCode       = 0x2017
    case captureAlreadyTerminated = 0x2018
    case deviceBusy              = 0x2019
    case invalidParentObject     = 0x201A
    case invalidDevicePropFormat = 0x201B
    case invalidDevicePropValue  = 0x201C
    case invalidParameter        = 0x201D
    case sessionAlreadyOpen      = 0x201E
    case transactionCancelled    = 0x201F
    case specificationOfDestinationUnsupported = 0x2020
}

enum PTPIPPacketType: UInt32 {
    case initCommandRequest = 0x00000001
    case initCommandAck     = 0x00000002
    case initEventRequest   = 0x00000003
    case initEventAck       = 0x00000004
    case initFail           = 0x00000005
    case cmdRequest         = 0x00000006
    case cmdResponse        = 0x00000007
    case event              = 0x00000008
    case startData          = 0x00000009
    case data               = 0x0000000A
    case cancel             = 0x0000000B
    case endData            = 0x0000000C
    case probeRequest       = 0x0000000D
    case probeResponse      = 0x0000000E
}

enum PTPObjectFormatCode: UInt16 {
    case undefined   = 0x3000
    case jpeg        = 0x3801
    case tiff        = 0x3807
    case bmp         = 0x3804
    case png         = 0x380B
    case heif        = 0x3827
}
