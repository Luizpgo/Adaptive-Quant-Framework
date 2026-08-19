#ifndef __AQF_VOLUME_LIMIT_RESULT_MQH__
#define __AQF_VOLUME_LIMIT_RESULT_MQH__

enum ENUM_AQF_VOLUME_LIMIT_STATUS
{
   AQF_VOLUME_LIMIT_UNKNOWN = 0,
   AQF_VOLUME_LIMIT_ACCEPTED,
   AQF_VOLUME_LIMIT_REDUCED,
   AQF_VOLUME_LIMIT_REJECTED
};

class CAQFVolumeLimitResult
{
public:

   ENUM_AQF_VOLUME_LIMIT_STATUS Status;

   double VolumeByRisk;
   double VolumeByExposure;
   double VolumeByMargin;
   double VolumeByBroker;

   double FinalVolume;

   bool Valid;

   string Message;

   CAQFVolumeLimitResult()
   {
      Reset();
   }

   void Reset()
   {
      Status = AQF_VOLUME_LIMIT_UNKNOWN;

      VolumeByRisk     = 0.0;
      VolumeByExposure = 0.0;
      VolumeByMargin   = 0.0;
      VolumeByBroker   = 0.0;

      FinalVolume = 0.0;

      Valid = false;

      Message = "";
   }
};

string AQFVolumeLimitStatusToString(
   const ENUM_AQF_VOLUME_LIMIT_STATUS status)
{
   switch(status)
   {
      case AQF_VOLUME_LIMIT_ACCEPTED:
         return "ACCEPTED";

      case AQF_VOLUME_LIMIT_REDUCED:
         return "REDUCED";

      case AQF_VOLUME_LIMIT_REJECTED:
         return "REJECTED";

      default:
         return "UNKNOWN";
   }
}

#endif